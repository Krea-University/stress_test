@echo off
setlocal enabledelayedexpansion

echo ┌────────────────────────────────────────────────────────┐
echo │              Organizing Test Results                   │
echo └────────────────────────────────────────────────────────┘
echo.

:: Create results directory if it doesn't exist
if not exist "results" mkdir "results"

:: Move existing test folders to results directory
echo Moving existing test folders to results directory...
echo.

set MOVED_COUNT=0

:: Look for directories that aren't system folders
for /d %%i in (*) do (
    set DIRNAME=%%i
    
    :: Skip system directories and our new results directory
    if /i not "!DIRNAME!"=="results" (
        if /i not "!DIRNAME!"=="System" (
            if /i not "!DIRNAME!"=="Windows" (
                :: Check if directory contains test files (has .txt or .json files)
                dir "%%i\*.txt" >nul 2>&1
                if not errorlevel 1 (
                    echo Moving: %%i → results\%%i
                    if not exist "results\%%i" (
                        move "%%i" "results\" >nul 2>&1
                        if not errorlevel 1 (
                            set /a MOVED_COUNT+=1
                            echo   ✅ Moved successfully
                        ) else (
                            echo   ❌ Failed to move
                        )
                    ) else (
                        echo   ⚠️  Directory already exists in results
                    )
                ) else (
                    dir "%%i\*.json" >nul 2>&1
                    if not errorlevel 1 (
                        echo Moving: %%i → results\%%i
                        if not exist "results\%%i" (
                            move "%%i" "results\" >nul 2>&1
                            if not errorlevel 1 (
                                set /a MOVED_COUNT+=1
                                echo   ✅ Moved successfully
                            ) else (
                                echo   ❌ Failed to move
                            )
                        ) else (
                            echo   ⚠️  Directory already exists in results
                        )
                    )
                )
            )
        )
    )
)

echo.
echo ┌────────────────────────────────────────────────────────┐
echo │                    Summary                             │
echo └────────────────────────────────────────────────────────┘
echo.
echo Moved %MOVED_COUNT% test directories to results folder
echo.
echo New structure:
echo   iperf3.1.1_32\
echo   ├── results\
echo   │   ├── test1\
echo   │   ├── test2\
echo   │   ├── ...
echo   │   └── all_tests_summary.json
echo   └── iperf_test.bat
echo.
echo ✅ Organization complete!
echo.
pause