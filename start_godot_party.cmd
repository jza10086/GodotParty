@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0start_godot_party.ps1" -Interactive
endlocal
