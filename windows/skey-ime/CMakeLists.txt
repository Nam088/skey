add_library(skey-ime-core STATIC
    Host/CompositionHost.cpp
    Engine/CoreEngineAdapter.cpp
)
target_include_directories(skey-ime-core PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_LIST_DIR}/../../port/skey-capi/include
)

if(WIN32)
    target_sources(skey-ime-core PRIVATE
        EventHandling/Pipeline/WindowsKeyPipeline.cpp
        Service/WindowsImeService.cpp
        TSF/TsfTextService.cpp
        TSF/KeyEventSink.cpp
        IMM32/Imm32Fallback.cpp
        Registration/ProfileRegistrar.cpp
    )
    target_link_libraries(skey-ime-core PRIVATE ole32 uuid)

    # Native COM in-process server boundary. The portable core remains a
    # separate static library and is linked when the real text host is wired.
    add_library(skey-ime SHARED
        TSF/TsfTextService.cpp
        TSF/KeyEventSink.cpp
        Registration/ProfileRegistrar.cpp
        Registration/dllmain.cpp
    )
    target_include_directories(skey-ime PRIVATE ${CMAKE_CURRENT_LIST_DIR})
    target_compile_definitions(skey-ime PRIVATE UNICODE _UNICODE)
    target_link_libraries(skey-ime PRIVATE ole32 uuid)
    set_target_properties(skey-ime PROPERTIES OUTPUT_NAME "skey-ime")
endif()
