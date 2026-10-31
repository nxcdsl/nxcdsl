@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0.."

echo ==========================================================
echo   LumiGen - push code to GitHub (cloud macOS build)
echo ==========================================================
echo.
echo  Create an EMPTY repo on github.com first, then paste its URL.
echo  Example: https://github.com/yourname/lumigen.git
echo.
set /p REPO="Repo URL: "
if "%REPO%"=="" goto :end

where git >nul 2>nul
if errorlevel 1 (
  echo.
  echo [!] Git is not installed. Get it: https://git-scm.com/download/win
  pause
  exit /b 1
)

if not exist ".git" (
  git init -b main
  git config user.name "LumiGen"
  git config user.email "lumigen@local"
)

git add -A
git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" 2>nul

git remote remove origin 2>nul
git remote add origin "%REPO%"
git branch -M main

echo.
echo  Pushing... (a browser window may pop up asking you to sign in to GitHub)
echo.
git push -u origin main

echo.
echo ----------------------------------------------------------
echo  Push finished.
echo  Next: open your repo page -^> Actions tab
echo        -^> "Build unsigned IPA" -^> Run workflow
echo        -^> wait 5-8 min -^> download LumiGen-unsigned-ipa
echo ----------------------------------------------------------
echo.
pause
:end
