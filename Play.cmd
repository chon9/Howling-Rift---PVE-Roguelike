@echo off
set "RIFT_ENGINE=K:\Godot\Godot_v4.6.3-stable_win64.exe"
if exist "%RIFT_ENGINE%" (
  start "Howling Rift" "%RIFT_ENGINE%" --path "%~dp0."
) else (
  echo Open project.godot in Godot 4.3 or newer, then press F5.
  pause
)
