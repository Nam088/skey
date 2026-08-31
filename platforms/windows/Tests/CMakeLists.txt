cmake_minimum_required(VERSION 3.20)
project(skey_windows_contract_tests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC)
    set(SKEY_TEST_COMPILE_OPTIONS /W4 /WX /permissive-)
else()
    set(SKEY_TEST_COMPILE_OPTIONS -Wall -Wextra -Wpedantic -Werror)
endif()

# Rust staticlib (skey.lib / libskey.a) built from core/skey-capi.
find_library(SKEY_CORE_LIB
    NAMES skey
    PATHS
        "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/x86_64-pc-windows-msvc/release"
        "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/aarch64-apple-darwin/release"
        "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/x86_64-apple-darwin/release"
        "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/release"
    NO_DEFAULT_PATH)

# Typing modules required by TrayRuntime on Windows.
set(SKEY_TYPING_SOURCES "")
set(SKEY_TYPING_LIBS "")
if(WIN32)
    set(SKEY_TYPING_SOURCES
        ../skey-tray/Hook/KeyboardHook.cpp
        ../skey-tray/Hook/KeyClassifier.cpp
        ../skey-tray/Pipeline/TypingPipeline.cpp
        ../skey-tray/Pipeline/KeyInjector.cpp
        ../skey-tray/Pipeline/HotkeyManager.cpp
        ../skey-tray/Pipeline/ForegroundAppTracker.cpp
        ../skey-tray/Clipboard/ClipboardMonitor.cpp
        ../skey-tray/Clipboard/ClipboardPaster.cpp
        ../skey-tray/Clipboard/ClipboardPopup.cpp
        ../skey-tray/Engine/SKeyEngineWrapper.cpp
        ../skey-tray/Engine/MacroEngine.cpp
        ../Shared/Clipboard/ClipboardText.cpp
        ../Shared/Clipboard/ClipboardHistoryStore.cpp)
    if(SKEY_CORE_LIB)
        set(SKEY_TYPING_LIBS "${SKEY_CORE_LIB}" winmm advapi32 userenv ws2_32 bcrypt ntdll)
    else()
        message(WARNING
            "skey.lib not found; TrayRuntime-based tests will fail to link. "
            "Build it first: cargo build --release -p skey-capi --target x86_64-pc-windows-msvc (in core/)")
    endif()
endif()

enable_testing()

add_executable(skey_shared_services_tests
    SharedServicesTests.cpp
    ../Shared/Localization/LocalizationService.cpp
    ../Shared/Settings/SettingsStore.cpp
    ../skey-tray/TrayController.cpp
)
target_include_directories(skey_shared_services_tests PRIVATE ..)
add_test(NAME skey_shared_services_tests COMMAND skey_shared_services_tests)

add_executable(skey_windows_feature_matrix_tests
    WindowsFeatureMatrixTests.cpp
    ${SKEY_TYPING_SOURCES}
    ../Shared/Contracts/IpcCodec.cpp
    ../Shared/IPC/IpcTransport.cpp
    ../Shared/Localization/LocalizationService.cpp
    ../Shared/Settings/SettingsStore.cpp
    ../Shared/Settings/MacroStore.cpp
    ../Shared/Settings/SettingsPaths.cpp
    ../Shared/Clipboard/ClipboardText.cpp
    ../Shared/Clipboard/ClipboardHistoryStore.cpp
    ../skey-tray/TrayController.cpp
    ../skey-tray/TrayRuntime.cpp
)
target_include_directories(skey_windows_feature_matrix_tests PRIVATE ..)
target_compile_options(skey_windows_feature_matrix_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
target_link_libraries(skey_windows_feature_matrix_tests PRIVATE ${SKEY_TYPING_LIBS})
add_test(NAME skey_windows_feature_matrix_tests COMMAND skey_windows_feature_matrix_tests)

add_executable(skey_settings_viewmodel_tests
    SettingsViewModelTests.cpp
    ../Shared/Localization/LocalizationService.cpp
    ../Shared/Settings/SettingsStore.cpp
)
target_include_directories(skey_settings_viewmodel_tests PRIVATE ..)
target_compile_options(skey_settings_viewmodel_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_settings_viewmodel_tests COMMAND skey_settings_viewmodel_tests)

add_executable(skey_ipc_tray_tests
    IpcTransportTests.cpp
    ${SKEY_TYPING_SOURCES}
    ../Shared/Contracts/IpcCodec.cpp
    ../Shared/IPC/IpcTransport.cpp
    ../Shared/Settings/SettingsStore.cpp
    ../Shared/Settings/MacroStore.cpp
    ../Shared/Settings/SettingsPaths.cpp
    ../Shared/Clipboard/ClipboardText.cpp
    ../Shared/Clipboard/ClipboardHistoryStore.cpp
    ../skey-tray/TrayRuntime.cpp
)
target_include_directories(skey_ipc_tray_tests PRIVATE ..)
target_compile_options(skey_ipc_tray_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
target_link_libraries(skey_ipc_tray_tests PRIVATE ${SKEY_TYPING_LIBS})
add_test(NAME skey_ipc_tray_tests COMMAND skey_ipc_tray_tests)

add_executable(skey_tray_ipc_handler_tests
    TrayIpcHandlerTests.cpp
    ${SKEY_TYPING_SOURCES}
    ../skey-tray/TrayIpcHandler.cpp
    ../skey-tray/TrayRuntime.cpp
    ../Shared/Contracts/IpcCodec.cpp
    ../Shared/IPC/IpcTransport.cpp
    ../Shared/Settings/SettingsStore.cpp
    ../Shared/Settings/MacroStore.cpp
    ../Shared/Settings/SettingsPaths.cpp
    ../Shared/Clipboard/ClipboardText.cpp
    ../Shared/Clipboard/ClipboardHistoryStore.cpp
)
target_include_directories(skey_tray_ipc_handler_tests PRIVATE ..)
target_compile_options(skey_tray_ipc_handler_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
target_link_libraries(skey_tray_ipc_handler_tests PRIVATE ${SKEY_TYPING_LIBS})
add_test(NAME skey_tray_ipc_handler_tests COMMAND skey_tray_ipc_handler_tests)

add_executable(skey_feature_parity_tests FeatureParityTests.cpp)
target_include_directories(skey_feature_parity_tests PRIVATE ..)
target_compile_options(skey_feature_parity_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_feature_parity_tests COMMAND skey_feature_parity_tests)

add_executable(skey_hook_tests
    HookTests.cpp
    ../skey-tray/Hook/KeyClassifier.cpp
)
target_include_directories(skey_hook_tests PRIVATE ..)
target_compile_options(skey_hook_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_hook_tests COMMAND skey_hook_tests)

add_executable(skey_macro_engine_tests
    MacroEngineTests.cpp
    ../skey-tray/Engine/MacroEngine.cpp
)
target_include_directories(skey_macro_engine_tests PRIVATE ..)
target_compile_options(skey_macro_engine_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_macro_engine_tests COMMAND skey_macro_engine_tests)

add_executable(skey_typing_pipeline_tests
    TypingPipelineTests.cpp
    ../skey-tray/Hook/KeyClassifier.cpp
    ../skey-tray/Pipeline/TypingPipeline.cpp
    ../skey-tray/Pipeline/KeyInjector.cpp
    ../skey-tray/Pipeline/HotkeyManager.cpp
    ../skey-tray/Engine/MacroEngine.cpp
)
target_include_directories(skey_typing_pipeline_tests PRIVATE ..)
target_compile_options(skey_typing_pipeline_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
if(WIN32)
    target_link_libraries(skey_typing_pipeline_tests PRIVATE winmm)
endif()
add_test(NAME skey_typing_pipeline_tests COMMAND skey_typing_pipeline_tests)

add_executable(skey_phase2_runtime_tests
    Phase2RuntimeTests.cpp
    ../skey-tray/Hook/KeyClassifier.cpp
    ../skey-tray/Pipeline/TypingPipeline.cpp
    ../skey-tray/Pipeline/KeyInjector.cpp
    ../skey-tray/Pipeline/HotkeyManager.cpp
    ../skey-tray/Pipeline/ForegroundAppTracker.cpp
    ../skey-tray/Engine/MacroEngine.cpp
)
target_include_directories(skey_phase2_runtime_tests PRIVATE ..)
target_compile_options(skey_phase2_runtime_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
if(WIN32)
    target_link_libraries(skey_phase2_runtime_tests PRIVATE winmm)
endif()
add_test(NAME skey_phase2_runtime_tests COMMAND skey_phase2_runtime_tests)

if(SKEY_CORE_LIB)
    add_executable(skey_typing_vector_tests
        TypingVectorTests.cpp
        ../skey-tray/Engine/SKeyEngineWrapper.cpp
    )
    target_include_directories(skey_typing_vector_tests PRIVATE
        ..
        "${CMAKE_CURRENT_LIST_DIR}/../../../core/skey-capi/include")
    target_compile_options(skey_typing_vector_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
    if(WIN32)
        target_link_libraries(skey_typing_vector_tests PRIVATE "${SKEY_CORE_LIB}" advapi32 userenv ws2_32 bcrypt ntdll)
    else()
        target_link_libraries(skey_typing_vector_tests PRIVATE "${SKEY_CORE_LIB}")
    endif()
    add_test(NAME skey_typing_vector_tests COMMAND skey_typing_vector_tests)
endif()

add_executable(skey_clipboard_service_tests
    ClipboardServiceTests.cpp
)
target_include_directories(skey_clipboard_service_tests PRIVATE ..)
target_compile_options(skey_clipboard_service_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_clipboard_service_tests COMMAND skey_clipboard_service_tests)

add_executable(skey_clipboard_history_tests
    ClipboardHistoryTests.cpp
    ../Shared/Clipboard/ClipboardText.cpp
    ../Shared/Clipboard/ClipboardHistoryStore.cpp
)
target_include_directories(skey_clipboard_history_tests PRIVATE ..)
target_compile_options(skey_clipboard_history_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_clipboard_history_tests COMMAND skey_clipboard_history_tests)

add_executable(skey_settings_store_roundtrip_tests
    SettingsStoreRoundTripTests.cpp
    ../Shared/Settings/SettingsStore.cpp
)
target_include_directories(skey_settings_store_roundtrip_tests PRIVATE ..)
target_compile_options(skey_settings_store_roundtrip_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_settings_store_roundtrip_tests COMMAND skey_settings_store_roundtrip_tests)

add_executable(skey_keyboard_settings_tests
    KeyboardSettingsTests.cpp
    ../skey-settings/Shared/Shortcuts/HotkeyFormat.cpp
    ../skey-settings/Shared/Shortcuts/HotkeyStore.cpp
    ../Shared/Settings/SettingsStore.cpp
)
target_include_directories(skey_keyboard_settings_tests PRIVATE ..)
target_compile_options(skey_keyboard_settings_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_keyboard_settings_tests COMMAND skey_keyboard_settings_tests)

add_executable(skey_macro_store_tests
    MacroStoreTests.cpp
    ../Shared/Settings/MacroStore.cpp
)
target_include_directories(skey_macro_store_tests PRIVATE ..)
target_compile_options(skey_macro_store_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_macro_store_tests COMMAND skey_macro_store_tests)

add_executable(skey_settings_backup_tests
    SettingsBackupTests.cpp
    ../skey-settings/Shared/Settings/Backup/SettingsBackup.cpp
    ../Shared/Settings/SettingsStore.cpp
)
target_include_directories(skey_settings_backup_tests PRIVATE ..)
target_compile_options(skey_settings_backup_tests PRIVATE ${SKEY_TEST_COMPILE_OPTIONS})
add_test(NAME skey_settings_backup_tests COMMAND skey_settings_backup_tests)
