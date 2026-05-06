@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "BUILD_DIR=%PROJECT_DIR%build\windows"

cd /d "%PROJECT_DIR%"

where cmake >nul 2>nul
if errorlevel 1 (
    echo CMake ne nayden.
    echo Ustanovite CMake ili sobirayte proekt cherez Qt Creator.
    pause
    exit /b 1
)

echo Sborka proekta DBSCAN...
cmake -S "%PROJECT_DIR%" -B "%BUILD_DIR%"
if errorlevel 1 (
    pause
    exit /b 1
)

cmake --build "%BUILD_DIR%" --config Release
if errorlevel 1 (
    pause
    exit /b 1
)

set "APP_EXE=%BUILD_DIR%\Release\appDBSCAN.exe"
if not exist "%APP_EXE%" set "APP_EXE=%BUILD_DIR%\appDBSCAN.exe"

if not exist "%APP_EXE%" (
    echo Prilozhenie ne naydeno.
    echo Proverte papku %BUILD_DIR%
    pause
    exit /b 1
)

where windeployqt >nul 2>nul
if not errorlevel 1 (
    echo Kopiruyu biblioteki Qt ryadom s prilozheniem...
    windeployqt "%APP_EXE%"
) else (
    echo windeployqt ne nayden. Esli exe ne zapustitsya dvoinym klikom, otkroyte ego iz Qt Creator ili zapustite windeployqt vruchnuyu.
)

echo.
echo Gotovo.
echo Prilozhenie mozhno otkryt dvoinym klikom:
echo %APP_EXE%
pause
