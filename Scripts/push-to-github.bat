@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0.."

set "DEFAULT_REPO=https://github.com/nxcdsl/nxcdsl.git"

echo ==========================================================
echo   LumiGen - upload code to GitHub
echo ==========================================================
echo.
echo   Repo: %DEFAULT_REPO%
echo.
echo   Just press ENTER to use it  (or paste another URL)
echo.
set "REPO="
set /p REPO="Repo URL [Enter = default]: "
if "%REPO%"=="" set "REPO=%DEFAULT_REPO%"

where git >nul 2>nul
if errorlevel 1 (
  echo.
  echo [!] Git not found: https://git-scm.com/download/win
  pause
  exit /b 1
)

if not exist ".git" (
  git init -b main
  git config user.name "LumiGen"
  git config user.email "lumigen@local"
)

echo.
echo [1/3] staging...
git add -A
git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" >nul 2>nul

echo [2/3] remote: %REPO%
git remote remove origin >nul 2>nul
git remote add origin "%REPO%"
git branch -M main

echo [3/3] pushing (a browser window may pop up - sign in and click Authorize)
echo.
git push -u origin main
if errorlevel 1 goto :failed

echo.
echo ==========================================================
echo   SUCCESS
echo.
echo   The build starts automatically on GitHub.
echo   Opening the Actions page for you...
echo ==========================================================
echo.
start "" "%~dp0..\..\..\nul" >nul 2>nul
start "" "https://github.com/nxcdsl/nxcdsl/actions"
timeout /t 3 >nul
exit /b 0

:failed
echo.
echo ==========================================================
echo   [X] PUSH FAILED
echo.
echo   Screenshot this window and send it to me.
echo ==========================================================
echo.
pause
exit /b 1
