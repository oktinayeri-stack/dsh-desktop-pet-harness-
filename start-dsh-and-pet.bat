@echo off
rem One-click: start the pet, then run DeepSeek Harness (dsh web) in the foreground.
rem The pet auto-exits a few seconds after the terminal (dsh web) stops.
start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "E:\download\dsh-desktop-pet\pet.ps1"
where dsh >nul 2>nul
if %errorlevel%==0 (
  dsh web
) else (
  echo [pet] dsh command not found. Start DeepSeek Harness manually, then run start-pet.bat
  echo The pet is still running; press any key to close this window only.
  pause >nul
)
