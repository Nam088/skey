if(WIN32)
    # Minimal TSF text service loaded inside browsers (Phase 5). Receives
    # engine results from skey-tray.exe through the Shared/TsfBridge channel
    # and applies them as TSF edits at the caret.
    add_library(skey-tsf SHARED
        dllmain.cpp
        Guids.cpp
        ClassFactory.cpp
        TextService.cpp
        ApplyEditSession.cpp
        BridgeServer.cpp
        Register.cpp
        ../Shared/TsfBridge/TsfBridge.cpp
        skey-tsf.def)
    target_include_directories(skey-tsf PRIVATE ..)
    target_link_libraries(skey-tsf PRIVATE user32 ole32 advapi32)
endif()
