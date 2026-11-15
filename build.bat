@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"
set "LOG=%~dp0build_log.txt"
set "OUT=%~dp0Release"
set "SRC=%~dp0Source\HeroMod.cpp"
echo === Сборка HeroMod.asi ===

rem 1. Plugin-SDK: переменная PLUGIN_SDK_DIR или файл sdk_path.txt рядом с build.bat
if not defined PLUGIN_SDK_DIR if exist "%~dp0sdk_path.txt" set /p PLUGIN_SDK_DIR=<"%~dp0sdk_path.txt"
if not defined PLUGIN_SDK_DIR goto :nosdk
if "%PLUGIN_SDK_DIR:~-1%"=="\" set "PLUGIN_SDK_DIR=%PLUGIN_SDK_DIR:~0,-1%"
if not exist "%PLUGIN_SDK_DIR%\plugin_vc" goto :nosdk

rem 2. Visual Studio: 32-битные инструменты C++
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto :novs
set "VSPATH="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
if not defined VSPATH goto :novs
call "%VSPATH%\VC\Auxiliary\Build\vcvars32.bat" >nul
if errorlevel 1 goto :novs

rem 3. Библиотека Plugin_VC.lib (ищем внутри папки SDK)
set "SDKLIB="
for /f "delims=" %%f in ('dir /s /b "%PLUGIN_SDK_DIR%\Plugin_VC.lib" 2^>nul') do if not defined SDKLIB set "SDKLIB=%%f"
if not defined SDKLIB goto :nolib

rem 4. Пути к заголовкам и библиотекам
set "INCLUDE=%PLUGIN_SDK_DIR%\plugin_vc;%PLUGIN_SDK_DIR%\plugin_vc\game_vc;%PLUGIN_SDK_DIR%\plugin_vc\game_vc\enums;%PLUGIN_SDK_DIR%\shared;%PLUGIN_SDK_DIR%\shared\game;%PLUGIN_SDK_DIR%\shared\rwd3d9;%PLUGIN_SDK_DIR%\shared\dxsdk;%PLUGIN_SDK_DIR%\hooking;%PLUGIN_SDK_DIR%\safetyhook\include;%PLUGIN_SDK_DIR%;%INCLUDE%"
set "LIB=%PLUGIN_SDK_DIR%\output\lib;%PLUGIN_SDK_DIR%\shared\rwd3d9;%PLUGIN_SDK_DIR%\shared\dxsdk;%LIB%"
if defined DIRECTX9_SDK_DIR set "INCLUDE=%INCLUDE%;%DIRECTX9_SDK_DIR%\Include"
if defined DIRECTX9_SDK_DIR set "LIB=%LIB%;%DIRECTX9_SDK_DIR%\Lib\x86"

rem 4b. Автопоиск injector.hpp и rwcore.h (RenderWare) внутри Plugin-SDK
set "INJFOUND="
for /f "delims=" %%h in ('dir /s /b "%PLUGIN_SDK_DIR%\injector.hpp" 2^>nul') do if not defined INJFOUND call :addpath "%%~dph" INJFOUND
set "RWFOUND="
for /f "delims=" %%h in ('dir /s /b "%PLUGIN_SDK_DIR%\rwcore.h" 2^>nul') do if not defined RWFOUND call :addpath "%%~dph" RWFOUND

rem 5. Сборка
if not exist "%OUT%" mkdir "%OUT%"
if exist "%OUT%\HeroMod.asi" del /q "%OUT%\HeroMod.asi"
set "CPPSTD=/std:c++latest"
cl > "%LOG%" 2>&1
echo.>> "%LOG%"
echo Флаг стандарта: %CPPSTD%>> "%LOG%"
echo Компилирую...
cl /nologo /LD /MT /O2 /EHsc /Zc:threadSafeInit- %CPPSTD% /D_CRT_SECURE_NO_WARNINGS /D_CRT_NON_CONFORMING_SWPRINTFS /D_USE_MATH_DEFINES /DGTAVC /DPLUGIN_SGV_10EN /DNDEBUG "%SRC%" /Fo"%OUT%\\" /Fe"%OUT%\HeroMod.asi" /link "%SDKLIB%" user32.lib >> "%LOG%" 2>&1
if not exist "%OUT%\HeroMod.asi" goto :fail

rem 6. Если есть game_path.txt (путь к папке игры), копируем плагин сразу туда
set "GAMEDIR="
if exist "%~dp0game_path.txt" set /p GAMEDIR=<"%~dp0game_path.txt"
if not defined GAMEDIR goto :done
if not exist "%GAMEDIR%\gta-vc.exe" goto :done
copy /y "%OUT%\HeroMod.asi" "%GAMEDIR%\HeroMod.asi" >nul
echo Скопировано в папку игры: %GAMEDIR%

:done
echo.
echo ГОТОВО: %OUT%\HeroMod.asi
echo Положите его в папку игры рядом с gta-vc.exe и dinput8.dll.
if not defined CI pause
exit /b 0

:nosdk
echo.
echo Plugin-SDK не найден.
if not defined CI pause
exit /b 1

:novs
echo.
echo Не найдены инструменты C++ от Visual Studio.
if not defined CI pause
exit /b 1

:nolib
echo.
echo Не найдена библиотека Plugin_VC.lib в папке SDK.
if not defined CI pause
exit /b 1

:fail
echo.
echo ОШИБКА СБОРКИ. Первые найденные ошибки:
findstr /I /C:"error" "%LOG%"
echo.
echo Полный лог: %LOG%
if not defined CI pause
exit /b 1

:addpath
set "%~2=1"
set "D=%~1"
if "%D:~-1%"=="\" set "D=%D:~0,-1%"
set "INCLUDE=%INCLUDE%;%D%"
for %%p in ("%D%\..") do set "INCLUDE=%INCLUDE%;%%~fp"
echo Найден путь: %D%
exit /b 0
