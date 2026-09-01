#include "SharedViewModel.h"

#include "../../Shared/Settings/SettingsPaths.h"

namespace skey::windows {

SettingsViewModel& shared_view_model() {
    static SettingsViewModel instance{SettingsStore{SettingsPaths::settings_file()}};
    return instance;
}

} // namespace skey::windows
