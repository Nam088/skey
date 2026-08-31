#include "../skey-settings/ViewModels/SettingsViewModel.h"
#include "../Shared/Theme/ThemeResolver.h"

#include <cassert>
#include <iostream>

using namespace skey::windows;

int main() {
    SettingsViewModel vm;

    assert(vm.settings().locale == Locale::vi_vn);
    assert(vm.settings().theme == ThemeMode::system);
    assert(vm.settings().input_method == InputMethod::telex);
    assert(vm.settings().is_vietnamese);
    assert(vm.settings().spell_check);
    assert(vm.general_title() == "Chung");

    vm.set_locale(Locale::en_us);
    assert(vm.settings().locale == Locale::en_us);
    assert(vm.general_title() == "General");
    assert(vm.appearance_title() == "Appearance");

    vm.set_locale(Locale::vi_vn);
    assert(vm.general_title() == "Chung");

    vm.set_theme(ThemeMode::dark);
    assert(vm.settings().theme == ThemeMode::dark);

    vm.set_input_method(InputMethod::vni);
    assert(vm.settings().input_method == InputMethod::vni);

    vm.set_charset("tcvn3");
    assert(vm.settings().charset == "tcvn3");

    vm.set_vietnamese(false);
    assert(!vm.settings().is_vietnamese);

    vm.set_spell_check(false);
    assert(!vm.settings().spell_check);

    vm.set_free_marking(false);
    assert(!vm.settings().free_marking);

    vm.set_modern_style(true);
    assert(vm.settings().modern_style);

    vm.set_swallowed_key_restore(false);
    assert(!vm.settings().swallowed_key_restore);

    vm.set_quick_telex(true);
    assert(vm.settings().quick_telex);

    vm.set_quick_start_consonant(true);
    assert(vm.settings().quick_start_consonant);

    vm.set_quick_end_consonant(true);
    assert(vm.settings().quick_end_consonant);

    vm.set_upper_case_first_char(true);
    assert(vm.settings().upper_case_first_char);

    vm.set_allow_consonant_zfwj(true);
    assert(vm.settings().allow_consonant_zfwj);

    vm.set_smart_app_switch(true);
    assert(vm.settings().smart_app_switch);

    vm.set_launch_at_login(true);
    assert(vm.settings().launch_at_login);

    vm.set_check_updates(false);
    assert(!vm.settings().check_updates);

    vm.set_debug_mode(true);
    assert(vm.settings().debug_mode);

    vm.set_clipboard_enabled(false);
    assert(!vm.settings().clipboard_enabled);

    vm.set_clipboard_max_items(50);
    assert(vm.settings().clipboard_max_items == 50);

    vm.set_clipboard_auto_paste(false);
    assert(!vm.settings().clipboard_auto_paste);

    vm.set_clipboard_paste_plain_text(true);
    assert(vm.settings().clipboard_paste_plain_text);

    vm.set_clipboard_save_text(false);
    assert(!vm.settings().clipboard_save_text);

    vm.set_clipboard_save_images(true);
    assert(vm.settings().clipboard_save_images);

    vm.set_macro_enabled(false);
    assert(!vm.settings().macro_enabled);

    vm.set_macro_auto_caps(false);
    assert(!vm.settings().macro_auto_caps);

    vm.set_macro_in_english_mode(true);
    assert(vm.settings().macro_in_english_mode);

    vm.reset();
    assert(vm.settings().locale == Locale::vi_vn);
    assert(vm.settings().theme == ThemeMode::system);
    assert(vm.settings().input_method == InputMethod::telex);
    assert(vm.settings().is_vietnamese);
    assert(vm.settings().spell_check);
    assert(!vm.settings().modern_style);
    assert(!vm.settings().quick_telex);
    assert(!vm.settings().launch_at_login);
    assert(vm.settings().clipboard_enabled);
    assert(vm.settings().clipboard_max_items == 100);
    assert(vm.settings().macro_enabled);

    assert(!vm.general_title().empty());
    assert(!vm.keyboard_title().empty());
    assert(!vm.clipboard_title().empty());
    assert(!vm.shortcuts_title().empty());
    assert(!vm.snippets_title().empty());
    assert(!vm.tools_title().empty());
    assert(!vm.about_title().empty());
    assert(!vm.appearance_title().empty());

    assert(ThemeResolver::resolve(ThemeMode::system, false) == ResolvedTheme::light);
    assert(ThemeResolver::resolve(ThemeMode::system, true) == ResolvedTheme::dark);

    std::cout << "SETTINGS_VIEWMODEL_TESTS_OK\n";
    return 0;
}
