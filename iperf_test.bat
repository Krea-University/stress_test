@echo off
setlocal enabledelayedexpansion

:: === Configurations ===
set IP=34.180.16.45
set PORT=80
set PARALLEL_CONNECTIONS=32
set TIMEOUT=300

:: === Ask for Test Name ===
set /p TESTNAME=Enter Location Name: 

:: === Ask for File Size (default 100G) ===
set /p SIZE=Enter file size (default 100G): 
if "%SIZE%"=="" set SIZE=100G

:: === Paths ===
set RESULTSDIR=%~dp0results
set TESTDIR=%RESULTSDIR%\%TESTNAME%
set TIMESTAMP=%date:~10,4%-%date:~4,2%-%date:~7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=%TESTDIR%\%TESTNAME%_%TIMESTAMP%_report.txt
set JSONFILE=%TESTDIR%\results.json
set SUMMARYFILE=%TESTDIR%\results_summary.json
set GLOBALSUMMARY=%RESULTSDIR%\all_tests_summary.json

:: === Create folder structure if not exists ===
if not exist "%RESULTSDIR%" mkdir "%RESULTSDIR%"
if not exist "%TESTDIR%" mkdir "%TESTDIR%"

echo Running iperf3 test against %IP%:%PORT% with size %SIZE% (%PARALLEL_CONNECTIONS% parallel connections)...
echo ------------------------------------------------------------
echo Output will be displayed live and saved to: %LOGFILE%
echo ------------------------------------------------------------

:: === Run iperf3 with live progress animation ===
echo Starting iperf3 download test with %PARALLEL_CONNECTIONS% connections...
echo.

:: First run with live output - DOWNLOAD TEST with multiple connections
echo === Live Test Progress (Download Speed - %PARALLEL_CONNECTIONS% Parallel Connections) ===
echo Starting test... 
echo.

:: Create a temporary file for monitoring
set TEMPLOG=%TESTDIR%\temp_live.txt
del "%TEMPLOG%" 2>nul

:: Start iperf3 in background
echo Starting bandwidth test...
start /b cmd /c ".\iperf3.exe -c %IP% -p %PORT% -n %SIZE% -R -P %PARALLEL_CONNECTIONS% -t %TIMEOUT% --connect-timeout 5000 > \"%LOGFILE%\" 2>&1 && echo IPERF_DONE >> \"%TEMPLOG%\""

:: Animated progress display
echo.
echo ┌────────────────────────────────────────────────────────┐
echo │                    Download Progress                   │
echo └────────────────────────────────────────────────────────┘
echo.

set PROGRESS=0
set DOTS=0
:progress_loop
set /a PROGRESS+=1
if %PROGRESS% GTR 100 set PROGRESS=100

:: Create progress bar
set PROGRESSBAR=
set /a FILLED=%PROGRESS%/2
set /a EMPTY=50-%FILLED%

for /l %%i in (1,1,%FILLED%) do set PROGRESSBAR=!PROGRESSBAR!█
for /l %%i in (1,1,%EMPTY%) do set PROGRESSBAR=!PROGRESSBAR!░

:: Show current bandwidth if available
set CURRENT_SPEED=
if exist "%LOGFILE%" (
    for /f "tokens=6" %%a in ('findstr /c:"[SUM]" "%LOGFILE%" 2^>nul ^| tail -1') do set CURRENT_SPEED=%%a
)

:: Display progress
echo [!PROGRESSBAR!] %PROGRESS%%%
if defined CURRENT_SPEED (
    echo Current Speed: !CURRENT_SPEED! 
) else (
    echo Establishing connections...
)
echo Connections: %PARALLEL_CONNECTIONS% parallel streams
echo Server: %IP%:%PORT%

:: Check if iperf3 is done
if exist "%TEMPLOG%" (
    findstr /c:"IPERF_DONE" "%TEMPLOG%" >nul 2>&1
    if not errorlevel 1 goto :progress_done
)

:: Wait and continue
timeout /t 2 /nobreak >nul
cls
echo.
echo ┌────────────────────────────────────────────────────────┐
echo │                    Download Progress                   │
echo └────────────────────────────────────────────────────────┘
echo.

if %PROGRESS% LSS 100 goto :progress_loop

:progress_done
cls
echo.
echo ┌────────────────────────────────────────────────────────┐
echo │                  Test Complete!                       │
echo └────────────────────────────────────────────────────────┘
echo.

:: Clean up temp files
del "%TEMPLOG%" 2>nul

:: Check exit code
tasklist /fi "imagename eq iperf3.exe" 2>nul | find /i "iperf3.exe" >nul
if not errorlevel 1 (
    echo Waiting for test to complete...
    timeout /t 3 /nobreak >nul
)

set IPERF_EXIT_CODE=0
if exist "%LOGFILE%" (
    findstr /c:"error" "%LOGFILE%" >nul 2>&1
    if not errorlevel 1 set IPERF_EXIT_CODE=1
)

:: Show the results immediately
echo.
echo === Test Results ===
type "%LOGFILE%"

:: If successful, also get JSON results for logging
if %IPERF_EXIT_CODE% EQU 0 (
    echo.
    echo === Getting JSON results for logging ===
    .\iperf3.exe -c %IP% -p %PORT% -n %SIZE% -R -P %PARALLEL_CONNECTIONS% -t %TIMEOUT% --connect-timeout 5000 -J >> "%LOGFILE%" 2>&1
)

echo.
echo ------------------------------------------------------------
:: Check if we got meaningful data even with connection error
findstr /c "[SUM]" "%LOGFILE%" >nul 2>&1
if %errorlevel% EQU 0 (
    echo ✅ Test completed with some data (partial success)
    echo Note: Connection may have closed early but test data was collected
    set PARTIAL_SUCCESS=1
) else (
    set PARTIAL_SUCCESS=0
)

if %IPERF_EXIT_CODE% NEQ 0 (
    if %PARTIAL_SUCCESS% EQU 1 (
        echo ⚠️  iperf3 test had connection issues but collected data
        echo Check the results above - bandwidth measurements were successful
    ) else (
        echo ❌ iperf3 test failed with exit code: %IPERF_EXIT_CODE%
        echo Check the output above for error details.
    )
) else (
    echo ✅ iperf3 test completed successfully
)

:: === Create enhanced JSON entry if test was successful or had partial success ===
if %IPERF_EXIT_CODE% EQU 0 (
    set TEST_STATUS=success
) else if %PARTIAL_SUCCESS% EQU 1 (
    set TEST_STATUS=partial_success
) else (
    set TEST_STATUS=failed
)

:: Extract speed information from log file
set MAX_SPEED=0
set AVG_SPEED=0
set TOTAL_TRANSFERRED=0

if exist "%LOGFILE%" (
    for /f "tokens=6" %%a in ('findstr /c:"[SUM]" "%LOGFILE%" 2^>nul') do (
        set CURRENT_SPEED_RAW=%%a
        set CURRENT_SPEED=!CURRENT_SPEED_RAW:~0,-10!
        if !CURRENT_SPEED! GTR !MAX_SPEED! set MAX_SPEED=!CURRENT_SPEED!
    )
    
    for /f "tokens=4" %%b in ('findstr /c:"[SUM]" "%LOGFILE%" 2^>nul ^| tail -1') do set TOTAL_TRANSFERRED=%%b
)

if NOT "%TEST_STATUS%"=="failed" (
    (
    echo   {
    echo     "test_name": "%TESTNAME%",
    echo     "server_ip": "%IP%",
    echo     "server_port": "%PORT%",
    echo     "test_size": "%SIZE%",
    echo     "parallel_connections": "%PARALLEL_CONNECTIONS%",
    echo     "max_download_speed_mbps": "%MAX_SPEED%",
    echo     "total_data_transferred": "%TOTAL_TRANSFERRED%",
    echo     "test_type": "download",
    echo     "timestamp": "%TIMESTAMP%",
    echo     "date": "%date%",
    echo     "time": "%time%",
    echo     "logfile": "%LOGFILE%",
    echo     "status": "%TEST_STATUS%",
    echo     "timeout_seconds": "%TIMEOUT%"
    echo   }
    ) > "%TESTDIR%\_entry.json"

    :: === Append into per-test results.json ===
    call :appendJson "%JSONFILE%" "%TESTDIR%\_entry.json"
    
    :: === Append into summary results_summary.json ===
    call :appendJson "%SUMMARYFILE%" "%TESTDIR%\_entry.json"
    
    :: === Append into global summary (all tests) ===
    call :appendJson "%GLOBALSUMMARY%" "%TESTDIR%\_entry.json"

    del "%TESTDIR%\_entry.json"    echo.
    echo ✅ Test complete and results saved
    echo Results saved in: %LOGFILE%
    echo Summary updated in: %SUMMARYFILE%
    echo Global summary: %GLOBALSUMMARY%
    echo Maximum Speed: %MAX_SPEED% Mbps
    echo Data Transferred: %TOTAL_TRANSFERRED%
) else (
    echo.
    echo ❌ Test failed - results not saved to JSON files
    echo Error log saved in: %LOGFILE%
)
echo.
echo Press any key to exit...
pause >nul

:: === JSON append function ===
:appendJson
set TARGET=%~1
set ENTRY=%~2

if not exist "%TARGET%" (
    echo [> "%TARGET%"
    type "%ENTRY%" >> "%TARGET%"
    echo ]>> "%TARGET%"
    goto :eof
)

(for /f "delims=" %%x in ('type "%TARGET%" ^| findstr /v "]"') do echo %%x) > "%TARGET%.tmp"

for /f "usebackq tokens=* delims=" %%z in ("%ENTRY%") do (
    >> "%TARGET%.tmp" echo   ,%%z
)

echo ]>> "%TARGET%.tmp"
move /y "%TARGET%.tmp" "%TARGET%" >nul
goto :eof
