@echo off
:: ----------------------
:: Simple Kudu Deployment Script for .NET 6
:: Alternative deployment script that avoids MSBuild issues
:: ----------------------

echo.
echo ========================================
echo Simple Kudu Deployment - IIS App Pool Recycler
echo ========================================
echo.

setlocal enabledelayedexpansion

:: Set deployment paths
IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%~dp0%..\artifacts\wwwroot
)

echo Source: %DEPLOYMENT_SOURCE%
echo Target: %DEPLOYMENT_TARGET%
echo.

:: Ensure target directory exists
if not exist "%DEPLOYMENT_TARGET%" (
  echo Creating deployment target directory...
  mkdir "%DEPLOYMENT_TARGET%"
)

:: Check .NET 6.0
echo Checking .NET 6.0 runtime...
dotnet --version
IF %ERRORLEVEL% NEQ 0 (
  echo ERROR: .NET runtime not found
  exit /b 1
)

:: Check for project file
IF NOT EXIST "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" (
  echo ERROR: Project file not found: %DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj
  exit /b 1
)

:: Restore packages
echo.
echo Restoring NuGet packages...
dotnet restore "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" --verbosity minimal
IF %ERRORLEVEL% NEQ 0 (
  echo ERROR: Package restore failed
  exit /b 1
)

:: Publish application
echo.
echo Publishing application...
dotnet publish "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" ^
  --configuration Release ^
  --output "%DEPLOYMENT_TARGET%" ^
  --verbosity minimal ^
  --no-restore
IF %ERRORLEVEL% NEQ 0 (
  echo ERROR: Publish failed
  exit /b 1
)

:: Copy additional files
echo.
echo Copying additional files...

IF EXIST "%DEPLOYMENT_SOURCE%\web.config" (
  copy "%DEPLOYMENT_SOURCE%\web.config" "%DEPLOYMENT_TARGET%\web.config" > nul
  echo Copied web.config
)

IF EXIST "%DEPLOYMENT_SOURCE%\appsettings.Production.json" (
  copy "%DEPLOYMENT_SOURCE%\appsettings.Production.json" "%DEPLOYMENT_TARGET%\appsettings.Production.json" > nul
  echo Copied appsettings.Production.json
)

IF EXIST "%DEPLOYMENT_SOURCE%\README.md" (
  copy "%DEPLOYMENT_SOURCE%\README.md" "%DEPLOYMENT_TARGET%\README.md" > nul
  echo Copied README.md
)

echo.
echo ========================================
echo ✅ DEPLOYMENT COMPLETED SUCCESSFULLY
echo ========================================
echo.
echo Application deployed to: %DEPLOYMENT_TARGET%
echo.
echo Next steps:
echo 1. Test the API: https://your-site.azurewebsites.net/swagger
echo 2. Configure Uptime Kuma webhook: https://your-site.azurewebsites.net/api/webhook/uptime-kuma
echo.

endlocal
exit /b 0
