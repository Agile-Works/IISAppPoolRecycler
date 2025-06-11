@echo off
echo IIS App Pool Recycler - Starting...
echo.
echo This application requires administrator privileges to manage IIS.
echo Make sure you're running this as administrator.
echo.
echo Building application...
dotnet build --configuration Release
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Starting IIS App Pool Recycler...
echo Available on:
echo   HTTP:  http://localhost:5000
echo   HTTPS: https://localhost:5001
echo.
echo Press Ctrl+C to stop the application
echo.

dotnet run --configuration Release
