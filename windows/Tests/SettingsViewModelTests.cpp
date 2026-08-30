#include "../skey-settings/ViewModels/SettingsViewModel.h"
#include "../Shared/Theme/ThemeResolver.h"

#include <cassert>

using namespace skey::windows;

int main() {
    SettingsViewModel model;
    assert(model.settings().locale == Locale::vi_vn);
    assert(model.general_title() == "Chung");
    model.set_locale(Locale::en_us);
    assert(model.appearance_title() == "Appearance");
    model.set_theme(ThemeMode::dark);
    assert(model.settings().theme == ThemeMode::dark);
    model.set_input_method(InputMethod::vni);
    assert(model.settings().input_method == InputMethod::vni);
    model.reset();
    assert(model.settings().theme == ThemeMode::system);
    assert(model.general_title() == "Chung");
    assert(ThemeResolver::resolve(ThemeMode::system, false) == ResolvedTheme::light);
    return 0;
}
