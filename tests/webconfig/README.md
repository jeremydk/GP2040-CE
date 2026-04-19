# Webconfig regression harness

Live-device HTTP tests for the GP2040-CE webconfig API. Catches the classes of
bugs that tonight's debugging session turned up:

- Byte-0 corruption in HTTP response bodies (the `dG\0 dG\0` freelist-leak
  signature from before 6dab915a)
- Second-or-later-request corruption (same class, different trigger)
- Concurrent-connection serialization failures
- OOM-induced hangs (exercises many sequential allocations)
- Persistence of out-of-range `inputMode` values (post-2ed3ffda guard)

## Running

Device must be booted into webconfig mode and reachable. Default URL is the
Pico's USB RNDIS address.

```
just test-webconfig                          # uses http://192.168.7.1
just test-webconfig http://192.168.7.1       # explicit
bash tests/webconfig/harness.sh              # without just
```

Exits 0 on all-pass, 1 on failure, 2 on preflight failure (device unreachable).

## Dependencies

`bash`, `curl`, `jq`, `xxd` — all standard on macOS and most Linux distros.

## What's checked

| # | Test                       | Catches                                               |
|---|----------------------------|-------------------------------------------------------|
| 1 | Sequential read endpoints  | byte-0 corruption, invalid JSON, missing endpoints    |
| 2 | 20× repeated single endpoint | 2nd-or-later request corruption (libstdc++ SSO leak)  |
| 3 | 5× concurrent fetches      | per-connection state bugs                             |
| 4 | 100× stress                | heap fragmentation / exhaustion leading to hang       |
| 5 | inputMode round-trip       | 2ed3ffda regression (CONFIG persisted to storage)     |

## Adding a check

Each test is a bash function. Copy one of the existing tests in `harness.sh`,
tweak the endpoint or pattern, call it from `main()`. Use the helpers:

- `fetch_endpoint <name> <out-file>` — single GET, returns `status|size|content-type`
- `pass_log` / `fail_log` / `skip_log` — counters are tallied automatically

Keep per-test runtime short; the single-threaded device has ~264KB SRAM and
running thousands of requests in a loop can wedge it on pre-fix firmware.
