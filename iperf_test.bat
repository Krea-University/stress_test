@echo off
setlocal enabledelayedexpansion

:: === Configurations (optimized for iperf3 v3.1.1) ===
set IP=34.47.164.139
set PORT=80
set PARALLEL_CONNECTIONS=16

:: === Ask for Test Name ===
set /p TESTNAME=Enter Location Name: 

:: === Ask for File Size (default 1G, compatible with v3.1.1) ===
set /p SIZE=Enter file size (default 1G): 
if "%SIZE%"=="" set SIZE=1G

:: === Ask for Test Type ===
echo.
echo Test Options:
echo 1. Download only
echo 2. Upload only  
echo 3. Both (download + upload)
echo.
set /p TESTTYPE=Choose test type (1/2/3, default 3): 
if "%TESTTYPE%"=="" set TESTTYPE=3

:: === Paths ===         
set RESULTSDIR=%~dp0results
set TESTDIR=%RESULTSDIR%\%TESTNAME%
set TIMESTAMP=%date:~10,4%-%date:~4,2%-%date:~7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set DOWNLOAD_LOGFILE=%TESTDIR%\%TESTNAME%_%TIMESTAMP%_download_report.txt
set UPLOAD_LOGFILE=%TESTDIR%\%TESTNAME%_%TIMESTAMP%_upload_report.txt
set JSONFILE=%TESTDIR%\results.json
set SUMMARYFILE=%TESTDIR%\results_summary.json
set GLOBALSUMMARY=%RESULTSDIR%\all_tests_summary.json

:: === Create folder structure if not exists ===
if not exist "%RESULTSDIR%" mkdir "%RESULTSDIR%"
if not exist "%TESTDIR%" mkdir "%TESTDIR%"

echo Running iperf3 test against %IP%:%PORT% with size %SIZE% (%PARALLEL_CONNECTIONS% parallel connections)...
echo ------------------------------------------------------------
if "%TESTTYPE%"=="1" echo Test Mode: Download Only
if "%TESTTYPE%"=="2" echo Test Mode: Upload Only  
if "%TESTTYPE%"=="3" echo Test Mode: Both Download and Upload
echo ------------------------------------------------------------

:: === Run Download Test ===
if "%TESTTYPE%"=="1" goto :downloadTest
if "%TESTTYPE%"=="3" goto :downloadTest
if "%TESTTYPE%"=="2" goto :uploadTest

:downloadTest
echo.
echo === Starting Download Test ===
echo Output will be saved to: %DOWNLOAD_LOGFILE%
echo.

echo === Live Test Progress (Download Speed - %PARALLEL_CONNECTIONS% Parallel Connections) ===
echo Starting test... 
echo.

echo ==========================================================
echo                    Download Progress                   
echo ==========================================================
echo.
echo Connecting to %IP%:%PORT% with %PARALLEL_CONNECTIONS% connections...
echo Testing download speed (reverse mode)...
echo Test size: %SIZE%
echo.

:: Run iperf3 download test (v3.1.1 compatible)
.\iperf3.exe -c %IP% -p %PORT% -n %SIZE% -R -P %PARALLEL_CONNECTIONS% -f M > "%DOWNLOAD_LOGFILE%" 2>&1
set DOWNLOAD_EXIT_CODE=%ERRORLEVEL%

echo.
echo ==========================================================
echo                Download Test Completed                      
echo ==========================================================

:: Show the download results immediately
echo.
echo === Download Test Results ===
type "%DOWNLOAD_LOGFILE%"

call :processResults "%DOWNLOAD_LOGFILE%" %DOWNLOAD_EXIT_CODE% "download"

if "%TESTTYPE%"=="3" goto :uploadTest
if "%TESTTYPE%"=="1" goto :finalResults

:uploadTest
echo.
echo === Starting Upload Test ===
echo Output will be saved to: %UPLOAD_LOGFILE%
echo.

echo === Live Test Progress (Upload Speed - %PARALLEL_CONNECTIONS% Parallel Connections) ===
echo Starting test... 
echo.

echo ==========================================================
echo                     Upload Progress                   
echo ==========================================================
echo.
echo Connecting to %IP%:%PORT% with %PARALLEL_CONNECTIONS% connections...
echo Testing upload speed (normal mode)...
echo Test size: %SIZE%
echo.

:: Run iperf3 upload test (v3.1.1 compatible)
.\iperf3.exe -c %IP% -p %PORT% -n %SIZE% -P %PARALLEL_CONNECTIONS% -f M > "%UPLOAD_LOGFILE%" 2>&1
set UPLOAD_EXIT_CODE=%ERRORLEVEL%

echo.
echo ==========================================================
echo                 Upload Test Completed                      
echo ==========================================================

:: Show the upload results immediately
echo.
echo === Upload Test Results ===
type "%UPLOAD_LOGFILE%"

call :processResults "%UPLOAD_LOGFILE%" %UPLOAD_EXIT_CODE% "upload"

goto :finalResults
:finalResults
echo.
echo ==========================================================
echo                    Final Summary                      
echo ==========================================================
echo.
echo ✅ All tests completed!
echo Results saved in: %TESTDIR%
echo Summary updated in: %SUMMARYFILE%
echo Global summary: %GLOBALSUMMARY%
echo.
echo Press any key to exit...
pause >nul
goto :eof

:: === Process test results function ===
:processResults
set CURRENT_LOGFILE=%~1
set CURRENT_EXIT_CODE=%~2
set TEST_MODE=%~3

echo.
echo ------------------------------------------------------------
:: Check if we got meaningful data even with connection error
findstr /c:"[SUM]" "%CURRENT_LOGFILE%" >nul 2>&1
if %errorlevel% EQU 0 (
    echo ✅ %TEST_MODE% test completed with some data (partial success)
    echo Note: Connection may have closed early but test data was collected
    set PARTIAL_SUCCESS=1
) else (
    set PARTIAL_SUCCESS=0
)

if %CURRENT_EXIT_CODE% NEQ 0 (
    if %PARTIAL_SUCCESS% EQU 1 (
        echo ⚠️  iperf3 %TEST_MODE% test had connection issues but collected data
        echo Check the results above - bandwidth measurements were successful
    ) else (
        echo ❌ iperf3 %TEST_MODE% test failed with exit code: %CURRENT_EXIT_CODE%
        echo Check the output above for error details.
    )
) else (
    echo ✅ iperf3 %TEST_MODE% test completed successfully
)

:: === Create enhanced JSON entry if test was successful or had partial success ===
if %CURRENT_EXIT_CODE% EQU 0 (
    set TEST_STATUS=success
) else if %PARTIAL_SUCCESS% EQU 1 (
    set TEST_STATUS=partial_success
) else (
    set TEST_STATUS=failed
)

:: Extract speed information from log file (v3.1.1 compatible)
set MAX_SPEED=Unknown
set TOTAL_TRANSFERRED=Unknown

if exist "%CURRENT_LOGFILE%" (
    :: Get final summary data from the [SUM] line - get the last occurrence
    for /f "tokens=5,6" %%a in ('findstr /c:"[SUM]" "%CURRENT_LOGFILE%" 2^>nul ^| findstr /c:"sender"') do (
        set TOTAL_TRANSFERRED=%%a
        set MAX_SPEED=%%b
    )
    
    :: If no sender line found, try receiver line (for downloads in reverse mode)  
    if "!MAX_SPEED!"=="Unknown" (
        for /f "tokens=5,6" %%a in ('findstr /c:"[SUM]" "%CURRENT_LOGFILE%" 2^>nul ^| findstr /c:"receiver"') do (
            set TOTAL_TRANSFERRED=%%a
            set MAX_SPEED=%%b
        )
    )
)

if NOT "%TEST_STATUS%"=="failed" (
    if "%TEST_MODE%"=="download" (
        set SPEED_FIELD=max_download_speed_mbps
    ) else (
        set SPEED_FIELD=max_upload_speed_mbps
    )
    
    (
    echo   {
    echo     "test_name": "%TESTNAME%",
    echo     "server_ip": "%IP%",
    echo     "server_port": "%PORT%",
    echo     "test_size": "%SIZE%",
    echo     "parallel_connections": "%PARALLEL_CONNECTIONS%",
    echo     "!SPEED_FIELD!": "%MAX_SPEED%",
    echo     "total_data_transferred": "%TOTAL_TRANSFERRED%",
    echo     "test_type": "%TEST_MODE%",
    echo     "timestamp": "%TIMESTAMP%",
    echo     "date": "%date%",
    echo     "time": "%time%",
    echo     "logfile": "%CURRENT_LOGFILE%",
    echo     "status": "%TEST_STATUS%"
    echo   }
    ) > "%TESTDIR%\_entry_%TEST_MODE%.json"

    :: === Append into per-test results.json ===
    call :appendJson "%JSONFILE%" "%TESTDIR%\_entry_%TEST_MODE%.json"
    
    :: === Append into summary results_summary.json ===
    call :appendJson "%SUMMARYFILE%" "%TESTDIR%\_entry_%TEST_MODE%.json"
    
    :: === Append into global summary (all tests) ===
    call :appendJson "%GLOBALSUMMARY%" "%TESTDIR%\_entry_%TEST_MODE%.json"

    del "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo.
    echo ✅ %TEST_MODE% test complete and results saved
    echo %TEST_MODE% results saved in: %CURRENT_LOGFILE%
    echo Maximum %TEST_MODE% Speed: %MAX_SPEED% Mbps
    echo Data Transferred: %TOTAL_TRANSFERRED%
) else (
    echo.
    echo ❌ %TEST_MODE% test failed - results not saved to JSON files
    echo Error log saved in: %CURRENT_LOGFILE%
)
goto :eof

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

:: Remove the closing bracket, add comma and new entry, then add closing bracket back
(for /f "delims=" %%x in ('type "%TARGET%" ^| findstr /v "]"') do echo %%x) > "%TARGET%.tmp"
echo ,>> "%TARGET%.tmp"
type "%ENTRY%" >> "%TARGET%.tmp"
echo ]>> "%TARGET%.tmp"
move /y "%TARGET%.tmp" "%TARGET%" >nul
goto :eof
