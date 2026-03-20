@echo off
setlocal enabledelayedexpansion

echo.
echo ===== Step 1: Initializing git repository =====
if exist .git (
    echo Git repository already initialized
) else (
    git init
)

echo.
echo ===== Step 2: Adding all files =====
git add .

echo.
echo ===== Step 3: Committing changes =====
git commit -m "Initial commit"

echo.
echo ===== Step 4: Renaming branch to main =====
for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set CURRENT_BRANCH=%%i
if "%CURRENT_BRANCH%"=="main" (
    echo Branch is already named 'main'
) else (
    git branch -M main
)

echo.
echo ===== Step 5: Adding remote origin =====
for /f "tokens=*" %%i in ('git remote get-url origin 2^>nul') do set EXISTING_REMOTE=%%i
if "%EXISTING_REMOTE%"=="https://github.com/BartClo/pulse_track.git" (
    echo Remote origin already configured correctly
) else if not "!EXISTING_REMOTE!"=="" (
    echo Remote exists with different URL. Updating...
    git remote set-url origin https://github.com/BartClo/pulse_track.git
) else (
    git remote add origin https://github.com/BartClo/pulse_track.git
)

echo.
echo ===== Step 6: Pushing to remote origin =====
git push -u origin main

echo.
echo ===== Summary =====
echo Latest commits:
git --no-pager log --oneline -n 3
echo.
echo Remote configuration:
git remote -v

endlocal
