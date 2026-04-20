#include "addonmanager.h"
#include "usbhostmanager.h"

bool AddonManager::LoadAddon(GPAddon* addon) {
    if (addon->available()) {
        addon->setup();
        addons.push_back(addon);
        return true;
    } else {
        delete addon; // Don't use the memory if we don't have to
    }

    return false;
}

bool AddonManager::LoadUSBAddon(GPAddon* addon) {
    bool ret = LoadAddon(addon);
    if ( ret == true )
        USBHostManager::getInstance().pushListener(addon->getListener());
    return ret;
}

void AddonManager::ReinitializeAddons() {
    for (GPAddon* addon : addons) {
        addon->reinit();
    }
}

void AddonManager::PreprocessAddons() {
    for (GPAddon* addon : addons) {
        addon->preprocess();
    }
}

void AddonManager::ProcessAddons() {
    for (GPAddon* addon : addons) {
        addon->process();
    }
}

void AddonManager::PostprocessAddons(bool reportSent) {
    for (GPAddon* addon : addons) {
        addon->postprocess(reportSent);
    }
}

// HACK : change this for NeoPicoLED
GPAddon * AddonManager::GetAddon(std::string name) { // hack for NeoPicoLED
    for (GPAddon* addon : addons) {
        if (addon->name() == name)
            return addon;
    }
    return nullptr;
}
