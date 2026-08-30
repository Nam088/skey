if(WIN32)
    option(SKEY_BUILD_WINUI "Build WinUI 3 settings executable when toolchain is available" OFF)
    if(SKEY_BUILD_WINUI AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/SKey.Settings.vcxproj")
        add_executable(skey-settings WIN32 App/App.xaml App/App.xaml.h App/MainWindow.xaml App/MainWindow.xaml.h)
        target_compile_definitions(skey-settings PRIVATE UNICODE _UNICODE)
    else()
        # Keep CI deterministic on runners without the Windows App SDK.
        add_custom_target(skey-settings ALL
            COMMAND ${CMAKE_COMMAND} -E echo "WinUI 3 project staged; enable SKEY_BUILD_WINUI with Windows App SDK"
        )
    endif()
endif()

# The .sln/.vcxproj is the canonical WinUI/Visual Studio entry point. Keep a
# source manifest here for IDE discovery; CMake remains portable on macOS/Linux.
set(SKEY_SETTINGS_XAML
    App/App.xaml App/MainWindow.xaml
    Features/Settings/UI/SettingsDashboard.xaml
    Features/Settings/UI/Tabs/GeneralSettingsTab.xaml
    Features/Settings/UI/Tabs/KeyboardSettingsTab.xaml
    Features/Settings/UI/Tabs/ClipboardSettingsTab.xaml
    Features/Settings/UI/Tabs/SnippetsSettingsTab.xaml
    Features/Settings/UI/Tabs/ToolsSettingsTab.xaml
    Features/Settings/UI/Tabs/AboutSettingsTab.xaml)
