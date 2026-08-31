#pragma once

#include "../Contracts/SettingsModel.h"

#include <filesystem>

namespace skey::windows {

class SettingsStore final {
public:
    explicit SettingsStore(std::filesystem::path path);
    SettingsModel load() const;
    bool save(const SettingsModel& settings) const;
    bool reset() const;

private:
    std::filesystem::path path_;
};

} // namespace skey::windows
