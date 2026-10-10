@echo off
cd /d "%~dp0"
where godot >nul 2>nul
if %ERRORLEVEL% EQU 0 (godot --path . & exit /b)
echo Open project.godot in the tested Godot 4.7.2 stable, then press F5.
echo Official engine: https://godotengine.org/download/
pause
