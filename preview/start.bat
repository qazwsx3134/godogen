@echo off
where py >nul 2>&1
if %errorlevel%==0 (
    py -3 "%~dp0start.py" %*
) else (
    python "%~dp0start.py" %*
)
if errorlevel 1 pause
