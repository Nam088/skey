#pragma once

#include "../../../../Shared/Contracts/SettingsModel.h"
#include "../../../../Shared/Settings/SettingsStore.h"

#include <filesystem>
#include <string>

namespace skey::windows {

// Mirrors macOS SettingsBackupManager: snapshot export, validated import,
// factory reset. Filesystem + strings only so tests run cross-platform.
class SettingsBackup final {
public:
    static bool export_to_file(const SettingsModel& model,
                                const std::filesystem::path& destination,
                                const std::filesystem::path& macros_json_path = {});
    static bool import_from_file(const std::filesystem::path& source,
                                 SettingsModel& out,
                                 std::string* macros_json_out = nullptr);
    static bool factory_reset(const SettingsStore& store);
    static std::string default_backup_filename();
};

} // namespace skey::windows
