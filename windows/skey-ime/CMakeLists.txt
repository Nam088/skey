add_library(skey-ime-core STATIC
    Host/CompositionHost.cpp
    Host/TsfTextHost.cpp
    Engine/CoreEngineAdapter.cpp
    Engine/RustEngineStub.cpp
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

    add_library(skey-ime SHARED
        Registration/Guids.cpp
        Registration/ClassFactory.cpp
        Registration/ComExports.cpp
        Registration/dllmain.cpp
        Registration/skey-ime.def
    )
    target_include_directories(skey-ime PRIVATE ${CMAKE_CURRENT_LIST_DIR})
    target_compile_definitions(skey-ime PRIVATE UNICODE _UNICODE)
    target_link_libraries(skey-ime PRIVATE skey-ime-core ole32 uuid)
    set_target_properties(skey-ime PROPERTIES OUTPUT_NAME "skey-ime")
endif()
