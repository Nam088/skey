#include "../Shared/Contracts/SettingsModel.h"
#include "../Shared/Localization/LocalizationService.h"
#include "../Shared/Theme/ThemeResolver.h"
#include "../Shared/Settings/SettingsStore.h"
#include "../skey-tray/TrayController.h"

#include <cassert>
#include <filesystem>

using namespace skey::windows;

int main() {
    LocalizationService vi(Locale::vi_vn);
    assert(vi.text("settings.theme.light") == "Sáng");
    assert(vi.text("settings.theme.dark") == "Tối");
    vi.set_locale(Locale::en_us);
    assert(vi.text("settings.theme.light") == "Light");
    assert(vi.text("settings.theme.dark") == "Dark");
    assert(ThemeResolver::resolve(ThemeMode::system, true) == ResolvedTheme::dark);
    assert(ThemeResolver::resolve(ThemeMode::light, true) == ResolvedTheme::light);
    TrayController tray;
    assert(tray.start() && tray.is_running());
    tray.stop();
    assert(!tray.is_running());
    const auto path = std::filesystem::temp_directory_path() / "skey-settings-test.json";
    SettingsStore store(path);
    SettingsModel saved{};
    saved.locale = Locale::en_us;
    saved.theme = ThemeMode::dark;
    saved.input_method = InputMethod::vni;
    assert(store.save(saved));
    const auto loaded = store.load();
    assert(loaded.locale == Locale::en_us && loaded.theme == ThemeMode::dark);
    assert(loaded.input_method == InputMethod::vni);
    assert(store.reset());
    return 0;
}
