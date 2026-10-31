@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0.."

echo ==========================================================
echo   LumiGen - push code to GitHub (then cloud build)
echo ==========================================================
echo.
echo  Paste the URL of your EMPTY repo, ending with .git
echo  Example: https://github.com/yourname/lumigen.git
echo.
set /p REPO="Repo URL: "
if "%REPO%"=="" goto :end

where git >nul 2>nul
if errorlevel 1 (
  echo.
  echo [!] Git not found. Install it first: https://git-scm.com/download/win
  pause
  exit /b 1
)

if not exist ".git" (
  git init -b main
  git config user.name "LumiGen"
  git config user.email "lumigen@local"
)

echo.
echo [1/3] staging files...
git add -A
git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" >nul 2>nul

echo [2/3] connecting to %REPO%
git remote remove origin >nul 2>nul
git remote add origin "%REPO%"
git branch -M main

echo [3/3] pushing. A browser window may ask you to sign in to GitHub.
echo.
git push -u origin main
if errorlevel 1 goto :failed

echo.
echo ==========================================================
echo   SUCCESS - code is on GitHub
echo.
echo   Next:
echo     1. open your repo page in the browser
echo     2. click the "Actions" tab
echo     3. click "Build unsigned IPA" on the left
echo     4. click "Run workflow" (right side) then the green button
echo     5. wait 5-8 min, download the artifact at the bottom
echo ==========================================================
echo.
start "" "%REPO:.git=%/actions"
pause
exit /b 0

:failed
echo.
echo ==========================================================
echo   [X] PUSH FAILED
echo.
echo   Most common cause: the repo was created WITH a README
echo   or .gitignore, so it already has content.
echo.
echo   Fix: delete that repo on GitHub, create a new one,
echo   and do NOT tick any "Initialize this repository" box.
echo.
echo   Screenshot this window and send it to me if unsure.
echo ==========================================================
echo.
pause
exit /b 1

:end
echo Cancelled.
pause
