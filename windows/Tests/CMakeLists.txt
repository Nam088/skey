cmake_minimum_required(VERSION 3.20)
project(skey_windows_contract_tests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(skey_composition_host_tests
    CompositionHostTests.cpp
    ../skey-ime/Host/CompositionHost.cpp
)
target_include_directories(skey_composition_host_tests PRIVATE ../skey-ime)

if(MSVC)
    target_compile_options(skey_composition_host_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_composition_host_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

enable_testing()
add_test(NAME skey_composition_host_tests COMMAND skey_composition_host_tests)

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
    ../Shared/Contracts/IpcCodec.cpp
    ../Shared/IPC/IpcTransport.cpp
    ../Shared/Localization/LocalizationService.cpp
    ../Shared/Settings/SettingsStore.cpp
    ../skey-tray/TrayController.cpp
    ../skey-tray/TrayRuntime.cpp
)
target_include_directories(skey_windows_feature_matrix_tests PRIVATE ..)
if(MSVC)
    target_compile_options(skey_windows_feature_matrix_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_windows_feature_matrix_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_windows_feature_matrix_tests COMMAND skey_windows_feature_matrix_tests)

add_executable(skey_settings_viewmodel_tests
    SettingsViewModelTests.cpp
    ../Shared/Localization/LocalizationService.cpp
)
target_include_directories(skey_settings_viewmodel_tests PRIVATE ..)
if(MSVC)
    target_compile_options(skey_settings_viewmodel_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_settings_viewmodel_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_settings_viewmodel_tests COMMAND skey_settings_viewmodel_tests)

add_executable(skey_ipc_tray_tests
    IpcTransportTests.cpp
    ../Shared/Contracts/IpcCodec.cpp
    ../Shared/IPC/IpcTransport.cpp
    ../skey-tray/TrayRuntime.cpp
)
target_include_directories(skey_ipc_tray_tests PRIVATE ..)
if(MSVC)
    target_compile_options(skey_ipc_tray_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_ipc_tray_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_ipc_tray_tests COMMAND skey_ipc_tray_tests)

add_executable(skey_tray_ipc_handler_tests
    TrayIpcHandlerTests.cpp
    ../skey-tray/TrayIpcHandler.cpp
    ../skey-tray/TrayRuntime.cpp
    ../Shared/Contracts/IpcCodec.cpp
    ../Shared/IPC/IpcTransport.cpp
)
target_include_directories(skey_tray_ipc_handler_tests PRIVATE ..)
if(MSVC)
    target_compile_options(skey_tray_ipc_handler_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_tray_ipc_handler_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_tray_ipc_handler_tests COMMAND skey_tray_ipc_handler_tests)

add_executable(skey_feature_parity_tests FeatureParityTests.cpp)
target_include_directories(skey_feature_parity_tests PRIVATE ..)
if(MSVC)
    target_compile_options(skey_feature_parity_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_feature_parity_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_feature_parity_tests COMMAND skey_feature_parity_tests)

add_executable(skey_key_event_tests KeyEventSinkTests.cpp)
target_include_directories(skey_key_event_tests PRIVATE ../skey-ime)
if(MSVC)
    target_compile_options(skey_key_event_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_key_event_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_key_event_tests COMMAND skey_key_event_tests)

add_executable(skey_pipeline_tests
    WindowsKeyPipelineTests.cpp
    ../skey-ime/Host/CompositionHost.cpp
    ../skey-ime/EventHandling/Pipeline/WindowsKeyPipeline.cpp
)
target_include_directories(skey_pipeline_tests PRIVATE ../skey-ime)
if(MSVC)
    target_compile_options(skey_pipeline_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_pipeline_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_pipeline_tests COMMAND skey_pipeline_tests)

add_executable(skey_clipboard_service_tests
    ClipboardServiceTests.cpp
)
target_include_directories(skey_clipboard_service_tests PRIVATE ..)
if(MSVC)
    target_compile_options(skey_clipboard_service_tests PRIVATE /W4 /WX /permissive-)
else()
    target_compile_options(skey_clipboard_service_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME skey_clipboard_service_tests COMMAND skey_clipboard_service_tests)
