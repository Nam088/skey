cmake_minimum_required(VERSION 3.20)

# Portable staging package for CI and local smoke validation. A signed MSIX
# project can consume the same staged files in a later release job.
set(SKEY_PACKAGE_DIR "${CMAKE_CURRENT_BINARY_DIR}/package")
add_custom_target(skey-package ALL
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${SKEY_PACKAGE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SKEY_PACKAGE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E echo "SKey Windows package staging: ${SKEY_PACKAGE_DIR}"
    COMMENT "Stage Windows binaries for installer packaging"
)
if(TARGET skey-tray)
    add_dependencies(skey-package skey-tray)
endif()

add_custom_command(TARGET skey-package POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:skey-tray>" "${SKEY_PACKAGE_DIR}/skey-tray.exe"
    COMMAND ${CMAKE_COMMAND} -E tar cf "${CMAKE_CURRENT_BINARY_DIR}/skey-windows.zip" --format=zip --
            "${SKEY_PACKAGE_DIR}"
    VERBATIM
)
