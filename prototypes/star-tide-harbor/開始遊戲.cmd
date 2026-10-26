@echo off
setlocal
set "GODOT=C:\Users\qazws\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
if defined GODOT_BIN set "GODOT=%GODOT_BIN%"
if not exist "%GODOT%" (
  echo Godot 4.7 was not found. Set GODOT_BIN to your Godot executable.
  pause
  exit /b 1
)
start "Star Tide Harbor" "%GODOT%" --path "%~dp0."
endlocal
