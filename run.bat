@echo off
cd /d "%~dp0"
where godot >nul 2>nul
if %ERRORLEVEL% EQU 0 (godot --path . & exit /b)
echo Open project.godot in Godot 4.6 or later, then press F5.
echo Official engine: https://godotengine.org/download/
pause
