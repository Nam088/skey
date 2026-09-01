@echo off
REM SKey Windows Build Script (keyboard-hook architecture)
REM Usage: build-windows.bat [clean|build|test|all]

setlocal enabledelayedexpansion

set BUILD_DIR=build
set CONFIG=Release

if "%1"=="clean" goto :clean
if "%1"=="build" goto :build
if "%1"=="test" goto :test
if "%1"=="all" goto :all
if "%1"=="" goto :all

echo Usage: build-windows.bat [clean^|build^|test^|all]
exit /b 1

:clean
echo Cleaning build directory...
if exist %BUILD_DIR% rmdir /s /q %BUILD_DIR%
echo Clean complete.
exit /b 0

:build
echo Building Rust core (skey.lib)...
where cargo >nul 2>nul
if %errorlevel%==0 (
    pushd ..\..\core
    cargo rustc --release -p skey-capi --target x86_64-pc-windows-msvc --crate-type staticlib
    if errorlevel 1 (
        echo Rust build failed!
        popd
        exit /b 1
    )
    popd
) else (
    echo cargo not found - skey-tray.exe needs skey.lib to link.
    echo Install Rust or build core/skey-capi manually.
)

echo Configuring CMake...
if not exist %BUILD_DIR% mkdir %BUILD_DIR%
cd %BUILD_DIR%
cmake ../build-config -DSKEY_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=%CONFIG%
if errorlevel 1 (
    echo CMake configuration failed!
    exit /b 1
)

echo Building...
cmake --build . --config %CONFIG%
if errorlevel 1 (
    echo Build failed!
    exit /b 1
)

echo Build complete.
cd ..
exit /b 0

:test
echo Running tests...
if not exist %BUILD_DIR% (
    echo Build directory not found. Run 'build' first.
    exit /b 1
)
cd %BUILD_DIR%
ctest -C %CONFIG% --output-on-failure
if errorlevel 1 (
    echo Tests failed!
    exit /b 1
)

echo All tests passed.
cd ..
exit /b 0

:all
call :clean
if errorlevel 1 exit /b 1
call :build
if errorlevel 1 exit /b 1
call :test
if errorlevel 1 exit /b 1

echo.
echo ========================================
echo Build and test complete!
echo ========================================
exit /b 0
