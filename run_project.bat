@echo off
echo Starting My Journal App (Full Stack)...

:: Launch Backend in a new window
echo Starting Backend...
start "Journal Backend" cmd /k "call run_backend.bat"

:: Wait a moment for backend to initialize
timeout /t 5 /nobreak >nul

:: Launch Frontend in a new window
echo Starting Frontend...
start "Journal Frontend" cmd /k "call run_app.bat"

echo.
echo ---------------------------------------------------
echo Project is running!
echo - Backend window: Python API logs
echo - Frontend window: Flutter logs & Hot Reload (r)
echo ---------------------------------------------------
echo.
pause
