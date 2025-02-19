@REM Copyright (c) Microsoft. All rights reserved.
@REM Licensed under the MIT license. See LICENSE file in the project root for full license information.

@setlocal EnableExtensions EnableDelayedExpansion
@echo off

set current-path=%~dp0
rem // remove trailing slash
set current-path=%current-path:~0,-1%

set build-root=%current-path%\..\..
rem // resolve to fully qualified path
for %%i in ("%build-root%") do set build-root=%%~fi

set repo_root=%build-root%\..\..
rem // resolve to fully qualified path
for %%i in ("%repo_root%") do set repo_root=%%~fi

echo Build Root: %build-root%
echo Repo Root: %repo_root%

set cmake-root=%build-root%
rem -----------------------------------------------------------------------------
rem -- check prerequisites
rem -----------------------------------------------------------------------------

rem -----------------------------------------------------------------------------
rem -- parse script arguments
rem -----------------------------------------------------------------------------

rem // default build options
set build-clean=0
set build-config=Debug
set build-platform=Win32
set CMAKE_run_e2e_tests=OFF
set CMAKE_run_sfc_tests=OFF
set CMAKE_run_longhaul_tests=OFF
set CMAKE_run_unittests=OFF
set CMAKE_DIR=iotsdk_win32
set make=yes
set build_traceabilitytool=0
set prov_auth=OFF
set use_edge_modules=OFF

:args-loop
if "%1" equ "" goto args-done
if "%1" equ "-c" goto arg-build-clean
if "%1" equ "--clean" goto arg-build-clean
if "%1" equ "--config" goto arg-build-config
if "%1" equ "--platform" goto arg-build-platform
if "%1" equ "--run-e2e-tests" goto arg-run-e2e-tests
if "%1" equ "--run-sfc-tests" goto arg-run-sfc-tests
if "%1" equ "--run-longhaul-tests" goto arg-longhaul-tests
if "%1" equ "--run-unittests" goto arg-run-unittests
if "%1" equ "--cmake-root" goto arg-cmake-root
if "%1" equ "--no-make" goto arg-no-make
if "%1" equ "--build-traceabilitytool" goto arg-build-traceabilitytool
if "%1" equ "--provisioning" goto arg-provisioning
if "%1" equ "--use-edge-modules" goto arg-edge-modules
call :usage && exit /b 1

:arg-build-clean
set build-clean=1
goto args-continue

:arg-build-config
shift
if "%1" equ "" call :usage && exit /b 1
echo setting build-config to %1
set build-config=%1
goto args-continue

:arg-build-platform
shift
if "%1" equ "" call :usage && exit /b 1
set build-platform=%1
if %build-platform% == x64 (
    set CMAKE_DIR=iotsdk_x64
) else if %build-platform% == arm (
    set CMAKE_DIR=iotsdk_arm
)
goto args-continue

:arg-run-e2e-tests
set CMAKE_run_e2e_tests=ON
goto args-continue

:arg-run-sfc-tests
set CMAKE_run_sfc_tests=ON
goto args-continue

:arg-longhaul-tests
set CMAKE_run_longhaul_tests=ON
goto args-continue

:arg-run-unittests
set CMAKE_run_unittests=ON
goto args-continue

:arg-cmake-root
shift
if "%1" equ "" call :usage && exit /b 1
set cmake-root=%1
goto args-continue

:arg-no-make
set make=no
goto args-continue

:arg-build-traceabilitytool
set build_traceabilitytool=1
goto args-continue

:arg-provisioning
set prov_auth=ON
goto args-continue

:arg-edge-modules
set use_edge_modules=ON
goto args-continue

:args-continue
shift
goto args-loop

:args-done

if %make% == no (
    rem No point running tests if we are not building the code
    set CMAKE_run_e2e_tests=OFF
    set CMAKE_run_sfc_tests=OFF
    set CMAKE_run_longhaul_tests=OFF
)

rem -----------------------------------------------------------------------------
rem -- build with CMAKE and run tests
rem -----------------------------------------------------------------------------

if EXIST %cmake-root%\cmake (
    rmdir /s/q %cmake-root%\cmake
    rem no error checking
)

echo CMAKE Output Path: %cmake-root%\cmake
mkdir %cmake-root%\cmake
rem no error checking
pushd %cmake-root%\cmake

if %build-platform% == x64 (
    echo ***Running CMAKE for Win64***
    cmake -LAH -Drun_longhaul_tests:BOOL=%CMAKE_run_longhaul_tests% -Drun_e2e_tests:BOOL=%CMAKE_run_e2e_tests% -Drun_sfc_tests:BOOL=%CMAKE_run_sfc_tests% -Duse_cppunittest:BOOL=OFF -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -Duse_prov_client:BOOL=%prov_auth% -G "Visual Studio 15 2017" -A x64 -Duse_edge_modules=%use_edge_modules% -DCMAKE_BUILD_TYPE=$build_config
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
) else if %build-platform% == arm (
    echo ***Running CMAKE for ARM***
    cmake -LAH -Drun_longhaul_tests:BOOL=%CMAKE_run_longhaul_tests% -Drun_e2e_tests:BOOL=%CMAKE_run_e2e_tests% -Drun_sfc_tests:BOOL=%CMAKE_run_sfc_tests% -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -Duse_prov_client:BOOL=%prov_auth% -G "Visual Studio 15 2017" -A ARM  -Duse_edge_modules=%use_edge_modules% -DCMAKE_BUILD_TYPE=$build_config
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
) else (
    echo ***Running CMAKE for Win32***
    cmake -LAH -Drun_longhaul_tests:BOOL=%CMAKE_run_longhaul_tests% -Drun_e2e_tests:BOOL=%CMAKE_run_e2e_tests% -Drun_sfc_tests:BOOL=%CMAKE_run_sfc_tests% -Drun_unittests:BOOL=%CMAKE_run_unittests% %build-root% -Duse_prov_client:BOOL=%prov_auth% -G "Visual Studio 15 2017" -A Win32 -Duse_edge_modules=%use_edge_modules% -DCMAKE_BUILD_TYPE=$build_config
    if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
)

echo ***checking msbuild***
where /q msbuild
IF ERRORLEVEL 1 (
echo ***setting VC paths***
    IF EXIST "%ProgramFiles(x86)%\Microsoft Visual Studio\2017\Enterprise\Common7\Tools\VsMSBuildCmd.bat" call "%ProgramFiles(x86)%\Microsoft Visual Studio\2017\Enterprise\Common7\Tools\VsMSBuildCmd.bat"
)
where msbuild

if %make%==yes (
    echo build-config is %build-config%

    msbuild /m azure_iot_sdks.sln "-p:Configuration=%build-config%"
    if !ERRORLEVEL! neq 0 exit /b !ERRORLEVEL!
)

popd

if %build_traceabilitytool%==1 (
    rem invoke the traceabilitytool here instead of the second build step in Jenkins windows_c job
    msbuild /m %build-root%\tools\traceabilitytool\traceabilitytool.sln
    if !ERRORLEVEL! neq 0 exit /b !ERRORLEVEL!
)

goto :eof


rem -----------------------------------------------------------------------------
rem -- subroutines
rem -----------------------------------------------------------------------------

:clean-a-solution
call :_run-msbuild "Clean" %1 %2 %3
goto :eof


:build-a-solution
call :_run-msbuild "Build" %1 %2 %3
goto :eof

:usage
echo build.cmd [options]
echo options:
echo  -c, --clean                   delete artifacts from previous build before building
echo  --config ^<value^>            [Debug] build configuration (e.g. Debug, Release)
echo  --platform ^<value^>          [Win32] build platform (e.g. Win32, x64, arm, ...)
echo  --run-e2e-tests               run end-to-end tests
echo  --run-longhaul-tests          run long-haul tests
echo  --cmake-root                  Directory to place the cmake files used for building the project
echo  --no-make                     Surpress building the code
echo  --build-traceabilitytool      Builds an internal tool (traceabilitytool) to check for requirements/code/test consistency
echo  --run-unittests               Run unit tests
echo  --provisioning                Use Provisiong service
goto :eof


rem -----------------------------------------------------------------------------
rem -- helper subroutines
rem -----------------------------------------------------------------------------

:_run-msbuild
rem // optionally override configuration|platform
setlocal EnableExtensions
set build-target=
if "%~1" neq "Build" set "build-target=/t:%~1"
if "%~3" neq "" set build-config=%~3
if "%~4" neq "" set build-platform=%~4

msbuild /m %build-target% "/p:Configuration=%build-config%;Platform=%build-platform%" %2
if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
goto :eof

