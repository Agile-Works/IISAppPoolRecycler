@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 1.0.1 - Fixed for Kudu environments
:: ----------------------

echo.
echo ========================================
echo Kudu Deployment - IIS App Pool Recycler
echo ========================================
echo.

:: Prerequisites
:: -------------

:: Check if we're in a Kudu environment
IF DEFINED WEBSITE_SITE_NAME (
  echo Running in Azure App Service: %WEBSITE_SITE_NAME%
) ELSE (
  echo Running in local Kudu environment
)

:: Verify dotnet installed
where dotnet 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing dotnet.exe executable, please install .NET 6.0 runtime
  echo Download from: https://dotnet.microsoft.com/en-us/download/dotnet/6.0
  goto error
) ELSE (
  echo ✅ .NET CLI found
  dotnet --version
)

:: Verify node.js installed (for kudu sync)
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
) ELSE (
  echo ✅ Node.js found
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)

echo.
echo Deployment Configuration:
echo   Source: %DEPLOYMENT_SOURCE%
echo   Target: %DEPLOYMENT_TARGET%
echo   Manifest: %NEXT_MANIFEST_PATH%
echo.

goto Deployment

:: Utility Functions
:: -----------------

:SelectDotNetVersion

IF DEFINED KUDU_SELECT_DOTNET_VERSION (
  echo Selecting .NET version...
  call :ExitOnError dotnet --version
) ELSE (
  echo Using default .NET version
  dotnet --version
)

goto :EOF

:ExitOnError
set ERROR_CODE=%ERRORLEVEL%
if %ERROR_CODE% neq 0 (
  echo.
  echo ❌ An error has occurred during web site deployment.
  echo Error Code: !ERROR_CODE!
  echo Command: %*
  call :LogMessage !ERROR_CODE! %*
  goto error
)
goto :EOF

:LogMessage
echo %TIME% [ERROR] Error Code: %1 - Command: %2 %3 %4 %5 %6 %7 %8 %9
goto :EOF

:: Deployment
:: ----------

:Deployment
echo.
echo ========================================
echo Starting Deployment Process
echo ========================================

echo.
echo Step 1: Handling .NET Core Web Application deployment.

:: 1. Select .NET version
call :SelectDotNetVersion

echo.
echo Step 2: Restoring NuGet packages...
echo Command: dotnet restore "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj"
call :ExitOnError dotnet restore "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" --verbosity minimal

echo.
echo Step 3: Building and publishing application...
echo Command: dotnet publish "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" --output "%DEPLOYMENT_TARGET%" --configuration Release --verbosity minimal
call :ExitOnError dotnet publish "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" --output "%DEPLOYMENT_TARGET%" --configuration Release --verbosity minimal

echo.
echo Step 4: Synchronizing files with KuduSync...
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExitOnError "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd"
) ELSE (
  echo Skipping KuduSync (in-place deployment)
)

echo.
echo Step 5: Copying additional configuration files...
IF EXIST "%DEPLOYMENT_SOURCE%\start-windows.ps1" (
  echo Copying start-windows.ps1...
  copy "%DEPLOYMENT_SOURCE%\start-windows.ps1" "%DEPLOYMENT_TARGET%\start-windows.ps1" > nul
)

IF EXIST "%DEPLOYMENT_SOURCE%\start-windows.bat" (
  echo Copying start-windows.bat...
  copy "%DEPLOYMENT_SOURCE%\start-windows.bat" "%DEPLOYMENT_TARGET%\start-windows.bat" > nul
)

IF EXIST "%DEPLOYMENT_SOURCE%\DEPLOYMENT.md" (
  echo Copying DEPLOYMENT.md...
  copy "%DEPLOYMENT_SOURCE%\DEPLOYMENT.md" "%DEPLOYMENT_TARGET%\DEPLOYMENT.md" > nul
)

IF EXIST "%DEPLOYMENT_SOURCE%\README.md" (
  echo Copying README.md...
  copy "%DEPLOYMENT_SOURCE%\README.md" "%DEPLOYMENT_TARGET%\README.md" > nul
)

echo.
echo ✅ All files copied successfully!

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto end

:: Execute command
:ExecuteCmd
setlocal
set _CMD_=%*
echo Executing: %_CMD_%
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" (
  echo ❌ Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
  exit /b %ERRORLEVEL%
)
exit /b %ERRORLEVEL%

:error
endlocal
echo.
echo ========================================
echo ❌ DEPLOYMENT FAILED
echo ========================================
echo An error has occurred during web site deployment.
echo Error Code: %ERRORLEVEL%
echo.
echo Troubleshooting:
echo 1. Check that .NET 6.0 runtime is installed
echo 2. Verify the project builds locally: dotnet build
echo 3. Check Kudu deployment logs for more details
echo 4. Ensure all required files are in the repository
echo.
exit /b %ERRORLEVEL%

:end
endlocal
echo.
echo ========================================
echo ✅ DEPLOYMENT COMPLETED SUCCESSFULLY
echo ========================================
echo.
echo The IIS App Pool Recycler has been deployed successfully!
echo.
echo Next steps:
echo 1. Configure your IIS application to point to the deployment folder
echo 2. Test the API endpoints: /api/webhook/sites, /api/webhook/app-pools
echo 3. Configure Uptime Kuma with webhook URL: /api/webhook/uptime-kuma
echo 4. Monitor deployment logs for any issues
echo.
echo Deployment completed at: %DATE% %TIME%
echo.
