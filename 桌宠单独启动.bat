@echo off
cd /d "%~dp0"
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0pet\run-pet.ps1" -HarnessUrl "http://127.0.0.1:3080"
