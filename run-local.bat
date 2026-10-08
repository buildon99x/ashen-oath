@echo off
cd /d "%~dp0"

set "GODOT_DIR=D:\tools\godot"
set "GODOT_EXE="

for %%F in ("%GODOT_DIR%\Godot*console.exe" "%GODOT_DIR%\Godot*.exe" "%GODOT_DIR%\godot.exe") do (
    if not defined GODOT_EXE if exist "%%~fF" set "GODOT_EXE=%%~fF"
)

if not defined GODOT_EXE (
    echo Godot executable not found in %GODOT_DIR%
    pause
    exit /b 1
)

echo Starting Godot: %GODOT_EXE%
"%GODOT_EXE%" --path .