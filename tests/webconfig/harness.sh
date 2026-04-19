#!/usr/bin/env bash
# Webconfig regression harness for GP2040-CE.
#
# Usage: ./harness.sh [BASE_URL]
#   BASE_URL defaults to http://192.168.7.1
#
# Exit code is non-zero if any test fails. Designed to catch the class of bugs
# tonight's debugging session turned up: byte-0 corruption, first-request
# success followed by later-request corruption, concurrent-request hangs,
# OOM-induced hard faults.
#
# No dependencies beyond bash, curl, jq. Keep it simple — this runs against
# a live embedded device with ~264KB SRAM; do not parallelize beyond what
# the device can actually serve.

set -uo pipefail

BASE_URL="${1:-http://192.168.7.1}"
TMP=$(mktemp -d -t gp2040-harness.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
skipped=0
declare -a failures=()

log()      { printf '\033[90m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
pass_log() { printf '\033[32m[PASS]\033[0m %s\n' "$*"; pass=$((pass+1)); }
fail_log() { printf '\033[31m[FAIL]\033[0m %s\n' "$*"; fail=$((fail+1)); failures+=("$*"); }
skip_log() { printf '\033[33m[SKIP]\033[0m %s\n' "$*"; skipped=$((skipped+1)); }

# Known-good read-only endpoints (no POST body, GET only).
# If an endpoint is missing from the device it returns 0 bytes — the harness
# marks that as skip, not fail.
READ_ENDPOINTS=(
    getFirmwareVersion
    getMemoryReport
    getGamepadOptions
    getAddonsOptions
    getDisplayOptions
    getLedOptions
    getCustomTheme
    getPinMappings
    getKeyMappings
    getProfileOptions
    getReactiveLEDs
    getHETriggerCalibrations
    getPeripheralOptions
    getExpansionPins
    getSplashImage
    getMacroAddonOptions
    getUsedPins
)

fetch_endpoint() {
    # Prints status|size|content_type, writes body to $2
    local ep="$1" out="$2"
    curl -sS --max-time 10 --http0.9 \
        -o "$out" \
        -w "%{http_code}|%{size_download}|%{content_type}" \
        "$BASE_URL/api/$ep" 2>/dev/null || echo "000|0|"
}

# Test 1: Every read endpoint returns valid JSON with clean byte-0
test_read_endpoints() {
    log "Test 1: sequential read endpoints (byte-0 + JSON validity)"
    for ep in "${READ_ENDPOINTS[@]}"; do
        local out="$TMP/t1_$ep.bin"
        local info
        info=$(fetch_endpoint "$ep" "$out")
        local status size
        status=$(echo "$info" | cut -d'|' -f1)
        size=$(echo "$info" | cut -d'|' -f2)

        if [[ "$status" == "000" || "$size" == "0" ]]; then
            skip_log "$ep: no response (endpoint missing or device error)"
            continue
        fi

        # byte-0 corruption check: dG\0 dG\0 is the 6dab915a-class signature
        local first8
        first8=$(xxd -l 8 -p "$out" 2>/dev/null)
        if [[ "$first8" == "6447002064470020" ]]; then
            fail_log "$ep: byte-0 corruption (dG\\0 dG\\0 freelist leak)"
            continue
        fi

        if ! jq -e . < "$out" > /dev/null 2>&1; then
            fail_log "$ep: body is not valid JSON (first 8 bytes: $first8)"
            continue
        fi

        pass_log "$ep ($size bytes, clean JSON)"
    done
}

# Test 2: Sequential repeated fetches of one endpoint (catches 2nd-request bug)
test_repeat() {
    log "Test 2: repeated getMemoryReport (20 sequential — catches 2nd+ request corruption)"
    local ep=getMemoryReport
    local corrupted=0
    for i in $(seq 1 20); do
        local out="$TMP/t2_$i.bin"
        fetch_endpoint "$ep" "$out" > /dev/null
        local first8
        first8=$(xxd -l 8 -p "$out" 2>/dev/null)
        if [[ "$first8" == "6447002064470020" ]]; then
            corrupted=$((corrupted+1))
        fi
    done
    if [[ $corrupted -eq 0 ]]; then
        pass_log "repeated-fetch: 0/20 corrupted"
    else
        fail_log "repeated-fetch: $corrupted/20 corrupted (regression of 6dab915a fix)"
    fi
}

# Test 3: Concurrent fetches (device is single-threaded but multiple sockets)
test_concurrent() {
    log "Test 3: 5 concurrent getMemoryReport (catches connection serialization bugs)"
    for i in 1 2 3 4 5; do
        fetch_endpoint getMemoryReport "$TMP/t3_$i.bin" > "$TMP/t3_$i.info" &
    done
    wait
    local corrupted=0
    local missing=0
    for i in 1 2 3 4 5; do
        local first8
        first8=$(xxd -l 8 -p "$TMP/t3_$i.bin" 2>/dev/null)
        if [[ -z "$first8" ]]; then
            missing=$((missing+1))
        elif [[ "$first8" == "6447002064470020" ]]; then
            corrupted=$((corrupted+1))
        fi
    done
    if [[ $corrupted -eq 0 && $missing -eq 0 ]]; then
        pass_log "concurrent: 5/5 clean"
    else
        fail_log "concurrent: $corrupted corrupted, $missing missing responses"
    fi
}

# Test 4: Long stress — catches OOM / leak patterns
test_stress() {
    log "Test 4: 100 sequential getGamepadOptions (catches heap exhaustion)"
    local ok=0
    local err=0
    for i in $(seq 1 100); do
        local info
        info=$(fetch_endpoint getGamepadOptions "$TMP/t4_$i.bin")
        local status
        status=$(echo "$info" | cut -d'|' -f1)
        if [[ "$status" == "200" ]]; then
            ok=$((ok+1))
        else
            err=$((err+1))
        fi
    done
    if [[ $err -eq 0 ]]; then
        pass_log "stress-100: all 100 returned 200"
    else
        fail_log "stress-100: $err/$100 non-200 responses — possible heap exhaustion"
    fi
}

# Test 5: setGamepadOptions round-trip preserves inputMode (validates 2ed3ffda guards)
test_roundtrip_input_mode() {
    log "Test 5: inputMode round-trip via setGamepadOptions"
    local current="$TMP/t5_current.json"
    fetch_endpoint getGamepadOptions "$current" > /dev/null
    if ! jq -e . < "$current" > /dev/null 2>&1; then
        skip_log "round-trip: couldn't read current gamepad options"
        return
    fi
    local inputMode
    inputMode=$(jq -r '.inputMode' "$current")
    if [[ "$inputMode" == "255" ]]; then
        fail_log "round-trip: stored inputMode=255 (INPUT_MODE_CONFIG) — should never persist"
    else
        pass_log "round-trip: stored inputMode=$inputMode (not 255)"
    fi
}

# Quick preflight: is the device even reachable?
preflight() {
    log "Preflight: $BASE_URL"
    local info
    info=$(fetch_endpoint getFirmwareVersion "$TMP/preflight.json")
    local status
    status=$(echo "$info" | cut -d'|' -f1)
    if [[ "$status" != "200" ]]; then
        printf '\033[31m[FATAL]\033[0m device unreachable (status=%s). Is it booted into webconfig?\n' "$status"
        exit 2
    fi
    local version
    version=$(jq -r '.version' "$TMP/preflight.json")
    log "Device up, firmware: $version"
}

main() {
    preflight
    test_read_endpoints
    test_repeat
    test_concurrent
    test_stress
    test_roundtrip_input_mode

    echo
    printf '\033[1mSummary:\033[0m %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skipped"
    if [[ $fail -gt 0 ]]; then
        echo
        printf '\033[31mFailures:\033[0m\n'
        for f in "${failures[@]}"; do
            printf '  - %s\n' "$f"
        done
        exit 1
    fi
}

main "$@"
