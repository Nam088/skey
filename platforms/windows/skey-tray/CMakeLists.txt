if(WIN32)
    set(SKEY_CAPI_INCLUDE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../core/skey-capi/include")

    # Rust staticlib (skey.lib) built with:
    #   cargo build --release -p skey-capi --target x86_64-pc-windows-msvc
    find_library(SKEY_CORE_LIB
        NAMES skey
        PATHS
            "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/x86_64-pc-windows-msvc/release"
            "${CMAKE_CURRENT_LIST_DIR}/../../../core/target/release"
        NO_DEFAULT_PATH)

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
        Engine/SKeyEngineWrapper.cpp
        Engine/MacroEngine.cpp
        ../Shared/Contracts/IpcCodec.cpp
        ../Shared/IPC/IpcTransport.cpp)
    target_include_directories(skey-tray PRIVATE ../ "${SKEY_CAPI_INCLUDE_DIR}")
    target_link_libraries(skey-tray PRIVATE user32 shell32 gdi32 winmm)

    if(SKEY_CORE_LIB)
        target_link_libraries(skey-tray PRIVATE "${SKEY_CORE_LIB}" advapi32 userenv ws2_32 bcrypt ntdll)
    else()
        message(WARNING
            "skey.lib not found. Build it first: "
            "cargo build --release -p skey-capi --target x86_64-pc-windows-msvc (in core/)")
    endif()
endif()
