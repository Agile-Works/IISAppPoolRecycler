@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 1.0.0
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
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

goto Deployment

:: Utility Functions
:: -----------------

:SelectDotNetVersion

IF DEFINED KUDU_SELECT_DOTNET_VERSION (
  call :ExitOnError dotnet --version 2>&1
)

goto :EOF

:ExitOnError
set ERROR_CODE=%ERRORLEVEL%
if %ERROR_CODE% neq 0 (
  echo.
  echo An error has occurred during web site deployment.
  call :LogMessage !ERROR_CODE!
  goto error
)
goto :EOF

:LogMessage
echo %TIME% [ERROR] %*
goto :EOF

:: Deployment
:: ----------

:Deployment
echo Handling .NET Core Web Application deployment.

:: 1. Select .NET version
call :SelectDotNetVersion

:: 2. Restore packages
call :ExitOnError dotnet restore "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj"

:: 3. Build and publish
call :ExitOnError dotnet publish "%DEPLOYMENT_SOURCE%\IISAppPoolRecycler.csproj" --output "%DEPLOYMENT_TARGET%" --configuration Release

:: 4. KuduSync
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExitOnError "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd"
)

:: 5. Copy additional files
IF EXIST "%DEPLOYMENT_SOURCE%\start-windows.ps1" (
  copy "%DEPLOYMENT_SOURCE%\start-windows.ps1" "%DEPLOYMENT_TARGET%\start-windows.ps1"
)

IF EXIST "%DEPLOYMENT_SOURCE%\start-windows.bat" (
  copy "%DEPLOYMENT_SOURCE%\start-windows.bat" "%DEPLOYMENT_TARGET%\start-windows.bat"
)

IF EXIST "%DEPLOYMENT_SOURCE%\DEPLOYMENT.md" (
  copy "%DEPLOYMENT_SOURCE%\DEPLOYMENT.md" "%DEPLOYMENT_TARGET%\DEPLOYMENT.md"
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto end

:: Execute command
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :LogMessage %ERRORLEVEL%
exit /b %ERRORLEVEL%

:end
endlocal
echo Finished successfully.
