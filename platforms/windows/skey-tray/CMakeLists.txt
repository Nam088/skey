if(WIN32)
    set(SKEY_CAPI_INCLUDE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../core/skey-capi/include")

    # Rust staticlib built with (in core/):
    #   cargo rustc --release -p skey-capi --target x86_64-pc-windows-msvc --crate-type staticlib
    # Resolve the archive explicitly: a plain find_library can pick up the
    # cdylib import library, which drags a skey.dll dependency the exe
    # cannot satisfy at runtime (STATUS_DLL_NOT_FOUND, 0xC0000135).
    set(SKEY_CORE_LIB "")
    foreach(skey_target_dir
            "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/x86_64-pc-windows-msvc/release"
            "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/release")
        if(EXISTS "${skey_target_dir}/skey.lib")
            set(SKEY_CORE_LIB "${skey_target_dir}/skey.lib")
            break()
        endif()
    endforeach()

    add_executable(skey-tray WIN32
        TrayApp.cpp
        TrayController.cpp
        TrayRuntime.cpp
        TrayIpcHandler.cpp
        Hook/KeyboardHook.cpp
        Hook/KeyClassifier.cpp
        Pipeline/TypingPipeline.cpp
        Pipeline/KeyInjector.cpp
        Pipeline/HotkeyManager.cpp
        Pipeline/ForegroundAppTracker.cpp
        Clipboard/ClipboardMonitor.cpp
        Clipboard/ClipboardPaster.cpp
        Clipboard/ClipboardPopup.cpp
        System/LaunchAtLogin.cpp
        System/InputProfile.cpp
        Net/PlatformHttp.cpp
        Translator/TranslationHud.cpp
        UI/CleanerOverlay.cpp
        Engine/SKeyEngineWrapper.cpp
        Engine/MacroEngine.cpp
        ../Shared/Contracts/IpcCodec.cpp
        ../Shared/IPC/IpcTransport.cpp
        ../Shared/Localization/LocalizationService.cpp
        ../Shared/Settings/SettingsStore.cpp
        ../Shared/Settings/MacroStore.cpp
        ../Shared/Settings/SettingsPaths.cpp
        ../Shared/Clipboard/ClipboardText.cpp
        ../Shared/Clipboard/ClipboardHistoryStore.cpp
        ../Shared/Translator/TranslatorService.cpp
        ../Shared/TsfBridge/TsfBridge.cpp
        ../Shared/Updates/UpdateChecker.cpp)
    target_include_directories(skey-tray PRIVATE ../ "${SKEY_CAPI_INCLUDE_DIR}")
    # NOMINMAX: windows.h min/max macros break std::min/std::max.
    # UNICODE/_UNICODE: resource constants (IDC_ARROW, ...) must be wide.
    target_compile_definitions(skey-tray PRIVATE NOMINMAX UNICODE _UNICODE)
    target_link_libraries(skey-tray PRIVATE user32 shell32 gdi32 winmm ole32 advapi32 winhttp)

    if(SKEY_CORE_LIB)
        target_link_libraries(skey-tray PRIVATE "${SKEY_CORE_LIB}" advapi32 userenv ws2_32 bcrypt ntdll)
    else()
        message(WARNING
            "skey.lib not found. Build it first: "
            "cargo rustc --release -p skey-capi --target x86_64-pc-windows-msvc --crate-type staticlib (in core/)")
    endif()
endif()
