@echo off
rem Usage: mkf [component] [ALL] [Release]
rem   component - component to make
rem   ALL       - rebuild mode
rem   Release   - make in enduser mode

rem ============================================= Configure
set MAKE_SCRIPT_DIR=%~dp0\..\.scripts
set MAKE_CONFIG_FILE=%~dp0\.config.bsc

call "%MAKE_SCRIPT_DIR%\read_config.bat"  "%MAKE_CONFIG_FILE%"  MAKE  || exit /B 1 

set MAKE_TASK=%MAKE_DEFAULT_COMPONENT%
set MAKE_MODE_ALL=no
set MAKE_MODE_RELEASE=no

call :lbl_parse_argument %*  || exit /B 1

call "%MAKE_SCRIPT_DIR%\setenv.bat" %MAKE_ENVIRONMENT%  || exit /B 1

if "%WORKPLACE_DIR%" == "" call "%MAKE_SCRIPT_DIR%\setenv_workplace.bat"

pushd "%~dp0\%MAKE_TASK%"
call build.bat || (popd & exit /B 1)
popd
exit /B 0


rem ============================================= Parse Arguments
:lbl_parse_argument
if "%1" == "" goto :EOF

set IS_COMPONENT=no
for %%i in (%MAKE_ALL_COMPONENTS%) do if "%~1" == "%%i" set IS_COMPONENT=yes

if "%IS_COMPONENT%" == "yes" (
    set MAKE_TASK=%1
) else if "%~1" == "ALL" (
    set MAKE_MODE_ALL=yes
) else if "%~1" == "Release" (
    set MAKE_MODE_RELEASE=yes
) else ( 
    echo Invalid argument: %~nx0 %*
    echo.
    echo Usage: %~nx0 [component] [ALL] [Release]
    echo   component - component to make: %MAKE_ALL_COMPONENTS%
    echo   ALL       - rebuild mode
    echo   Release   - make in enduser mode
    exit /B 1
)
shift /1
goto :lbl_parse_argument 


rem ============================================= Script Messages
:lbl_Success
call "%MAKE_SCRIPT_DIR%\copy_extdeps.bat" "%MAKE_EXTDEPS%" "%~dp0\workplace" || goto lbl_Error
echo ============ %MAKE_TASK% ============ OK!
goto :EOF


:lbl_Error
echo *********** %MAKE_TASK% *********** Failed!
exit /B 1

