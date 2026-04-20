#ifndef _ADDONMANAGER_H_
#define _ADDONMANAGER_H_

#include "gpaddon.h"

#include <vector>

class AddonManager {
public:
    AddonManager() {}
    ~AddonManager() {}
    bool LoadAddon(GPAddon*);
    bool LoadUSBAddon(GPAddon*);
    void ReinitializeAddons();
    void PreprocessAddons();
    void ProcessAddons();
    void PostprocessAddons(bool);
    GPAddon * GetAddon(std::string); // hack for NeoPicoLED
private:
    std::vector<GPAddon*> addons;    // addons currently loaded
};

#endif
