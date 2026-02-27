@echo off
echo Starting Lumos Agent...
echo.
echo Configuration is loaded from lumos-config.json
echo Edit that file to change settings.
echo.
echo Web UI: http://127.0.0.1:8080/
echo Default credentials: lumos / change-me-secure-password
echo.
start "" "%~dp0lumos-agent.exe"
echo Lumos tray started. Check your system tray for the icon.
timeout /t 3
