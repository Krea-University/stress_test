@echo off
setlocal enabledelayedexpansion

:: === Command Line Arguments Support ===
:: Usage: iperf_test.bat [server_ip] [port] [test_size] [parallel_connections]
:: Example: iperf_test.bat ping.online.net 5201 100M 4::= Create enhanced JSON entry if test was successful or had partial success ===
if "%CURRENT_EXIT_CODE%"=="0" (
    set TEST_STATUS=success
) else (
    if "%PARTIAL_SUCCESS%"=="1" (
        set TEST_STATUS=partial_success
    ) else (
        set TEST_STATUS=failed
    )
)

:: === Configurations (optimized for iperf3 v3.1.1) ===
:: Keep server hardcoded as requested
set IP=34.47.164.139
set PORT=80
set PARALLEL_CONNECTIONS=16

:: === Get Local IP Address (Enhanced Detection) ===
set LOCAL_IP=Unknown

:: Method 1: Try to get primary network adapter IP
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address" 2^>nul') do (
    set TEMP_IP=%%a
    set TEMP_IP=!TEMP_IP: =!
    :: Skip loopback and empty addresses
    if not "!TEMP_IP!"=="127.0.0.1" if not "!TEMP_IP!"=="" (
        set LOCAL_IP=!TEMP_IP!
        goto :got_local_ip
    )
)

:: Method 2: If method 1 failed, try alternative approach
if "%LOCAL_IP%"=="Unknown" (
    for /f "tokens=1-4 delims=. " %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
        set TEMP_IP=%%d
        if not "!TEMP_IP!"=="127.0.0.1" if not "!TEMP_IP!"=="" (
            set LOCAL_IP=!TEMP_IP!
            goto :got_local_ip
        )
    )
)

:: Method 3: Use PowerShell as fallback
if "%LOCAL_IP%"=="Unknown" (
    for /f %%i in ('powershell -command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*'} | Select-Object -First 1).IPAddress" 2^>nul') do (
        set LOCAL_IP=%%i
    )
)

:got_local_ip
echo Detected Local IP: %LOCAL_IP%

:: === Ask for Test Name ===
set /p TESTNAME=Enter Location Name: 

echo.
echo === Test Configuration ===
echo Local IP: %LOCAL_IP%
echo Server: %IP%:%PORT%
echo Parallel Connections: %PARALLEL_CONNECTIONS%
echo.

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
set REPORTJSON=%TESTDIR%\%TESTNAME%_%TIMESTAMP%_test_report.json

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
if "%DOWNLOAD_EXIT_CODE%"=="" set DOWNLOAD_EXIT_CODE=0

echo.
echo ==========================================================
echo                Download Test Completed                      
echo ==========================================================

:: Show the download results immediately
echo.
echo === Download Test Results ===
type "%DOWNLOAD_LOGFILE%"

REM call :processResults "%DOWNLOAD_LOGFILE%" "%DOWNLOAD_EXIT_CODE%" "download"

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
if "%UPLOAD_EXIT_CODE%"=="" set UPLOAD_EXIT_CODE=0

echo.
echo ==========================================================
echo                 Upload Test Completed                      
echo ==========================================================

:: Show the upload results immediately
echo.
echo === Upload Test Results ===
type "%UPLOAD_LOGFILE%"

call :processResults "%UPLOAD_LOGFILE%" "%UPLOAD_EXIT_CODE%" "upload"

goto :finalResults
:finalResults
echo.
echo ==========================================================
echo                    Final Summary                      
echo ==========================================================
echo.
echo [SUCCESS] All tests completed!
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

:: Ensure exit code is numeric
if "%CURRENT_EXIT_CODE%"=="" set CURRENT_EXIT_CODE=0

echo.
echo ------------------------------------------------------------
:: Check if we got meaningful data even with connection error
findstr /c:"[SUM]" "%CURRENT_LOGFILE%" >nul 2>&1
if %errorlevel% EQU 0 (
    echo [SUCCESS] %TEST_MODE% test completed with some data (partial success)
    echo Note: Connection may have closed early but test data was collected
    set PARTIAL_SUCCESS=1
) else (
    set PARTIAL_SUCCESS=0
)

if "%CURRENT_EXIT_CODE%" NEQ "0" (
    if "%PARTIAL_SUCCESS%"=="1" (
        echo [WARNING] iperf3 %TEST_MODE% test had connection issues but collected data
        echo Check the results above - bandwidth measurements were successful
    ) else (
        echo [ERROR] iperf3 %TEST_MODE% test failed with exit code: %CURRENT_EXIT_CODE%
        echo Check the output above for error details.
    )
) else (
    echo [SUCCESS] iperf3 %TEST_MODE% test completed successfully
)

:: === Create enhanced JSON entry if test was successful or had partial success ===
if "%CURRENT_EXIT_CODE%"=="0" (
    set TEST_STATUS=success
) else if "%PARTIAL_SUCCESS%"=="1" (
    set TEST_STATUS=partial_success
) else (
    set TEST_STATUS=failed
)

:: Extract speed information from log file (v3.1.1 compatible)
set MAX_SPEED=Unknown
set TOTAL_TRANSFERRED=Unknown
set LOG_LOCAL_IP=Unknown

if exist "%CURRENT_LOGFILE%" (
    :: Extract local IP from connection log
    for /f "tokens=3" %%a in ('findstr /c:"local " "%CURRENT_LOGFILE%" 2^>nul ^| findstr /c:"connected"') do (
        set LOG_LOCAL_IP=%%a
        goto :got_log_ip
    )
    :got_log_ip
    
    :: Get final summary data from the [SUM] line - get the last occurrence
    :: Line format: [SUM]   0.00-27.33  sec  1.00 GBytes  37.5 MBytes/sec                  sender
    :: So tokens are: 1=[SUM] 2=interval 3=sec 4=amount 5=unit 6=speed 7=speed_unit 8=sender
    for /f "tokens=4,5,6,7" %%a in ('findstr /c:"[SUM]" "%CURRENT_LOGFILE%" 2^>nul ^| findstr /c:"sender"') do (
        set TOTAL_TRANSFERRED=%%a
        set TRANSFER_UNIT=%%b
        set MAX_SPEED=%%c
        set SPEED_UNIT=%%d
    )
    
    :: If no sender line found, try receiver line (for downloads in reverse mode)  
    if "!MAX_SPEED!"=="Unknown" (
        for /f "tokens=4,5,6,7" %%a in ('findstr /c:"[SUM]" "%CURRENT_LOGFILE%" 2^>nul ^| findstr /c:"receiver"') do (
            set TOTAL_TRANSFERRED=%%a
            set TRANSFER_UNIT=%%b
            set MAX_SPEED=%%c
            set SPEED_UNIT=%%d
        )
    )
)

if NOT "%TEST_STATUS%"=="failed" (
    if "%TEST_MODE%"=="download" (
        set SPEED_FIELD=max_download_speed_mbps
    ) else (
        set SPEED_FIELD=max_upload_speed_mbps
    )
    
    :: Extract numeric speed value and convert MBytes/sec to Mbps (Megabits per second)
    set SPEED_MBPS=0
    set SPEED_MBPS_PRECISE=0.0
    set SPEED_NUMERIC=Unknown
    
    :: Initialize all variables with defaults
    if "!LOG_LOCAL_IP!"=="" set LOG_LOCAL_IP=Unknown
    if "!TRANSFER_UNIT!"=="" set TRANSFER_UNIT=Unknown
    if "!TRANSFERRED_CLEAN!"=="" set TRANSFERRED_CLEAN=Unknown
    if not "!MAX_SPEED!"=="Unknown" (
        :: Display what we're parsing for debugging
        echo Parsing speed: "!MAX_SPEED!"
        
        :: Try simple approach - just get first token before space
        for /f "tokens=1" %%i in ("!MAX_SPEED!") do (
            set "SPEED_NUMERIC=%%i"
        )
        
        :: Convert MBytes/sec to Mbps (multiply by 8 for Megabits per second)
        if defined SPEED_NUMERIC (
            if not "!SPEED_NUMERIC!"=="Unknown" (
                :: For integer value (for compatibility)
                for /f "delims=." %%j in ("!SPEED_NUMERIC!") do (
                    set /a "SPEED_MBPS=%%j * 8" 2>nul || set "SPEED_MBPS=0"
                )
                
                :: For precise decimal calculation using PowerShell - handle variables safely
                if not "!SPEED_NUMERIC!"=="" if not "!SPEED_NUMERIC!"=="Unknown" (
                    for /f %%k in ('powershell -command "try { [math]::Round([double]'!SPEED_NUMERIC!' * 8, 2) } catch { Write-Output '0.0' }" 2^>nul') do (
                        set "SPEED_MBPS_PRECISE=%%k"
                    )
                ) else (
                    set "SPEED_MBPS_PRECISE=0.0"
                )
            )
        )
        
        echo Extracted numeric: "!SPEED_NUMERIC!" MBytes/sec converted to: !SPEED_MBPS_PRECISE! Mbps (Megabits per second)
    )
    
    :: Clean transferred data
    set TRANSFERRED_CLEAN=Unknown
    set TRANSFERRED_NUMERIC=Unknown
    if not "!TOTAL_TRANSFERRED!"=="Unknown" (
        echo Parsing transferred: "!TOTAL_TRANSFERRED!" !TRANSFER_UNIT!
        :: Now we have just the number in TOTAL_TRANSFERRED
        set "TRANSFERRED_NUMERIC=!TOTAL_TRANSFERRED!"
        set "TRANSFERRED_CLEAN=!TOTAL_TRANSFERRED!"
        echo Cleaned transferred: "!TRANSFERRED_CLEAN!" !TRANSFER_UNIT!
    )
    
    :: Create timestamp properly - simplified approach
    set "CLEAN_DATE=%date:~10,4%-%date:~4,2%-%date:~7,2%"
    set "CLEAN_TIME=%time:~0,2%-%time:~3,2%-%time:~6,2%"
    set "CLEAN_TIME=%CLEAN_TIME: =0%"
    set "CLEAN_TIMESTAMP=%CLEAN_DATE%_%CLEAN_TIME%"
    
    echo Creating JSON entry...
    
    :: Ensure all variables have safe values
    if "!SPEED_MBPS_PRECISE!"=="" set SPEED_MBPS_PRECISE=0.0
    if "!SPEED_NUMERIC!"=="" set SPEED_NUMERIC=0
    if "!TRANSFERRED_CLEAN!"=="" set TRANSFERRED_CLEAN=0
    if "!TRANSFER_UNIT!"=="" set TRANSFER_UNIT=MBytes
    if "!LOG_LOCAL_IP!"=="" set LOG_LOCAL_IP=Unknown
    
    echo {> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "test_name": "%TESTNAME%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "local_ip": "!LOG_LOCAL_IP!",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "local_ip_system": "%LOCAL_IP%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "server_ip": "%IP%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "server_port": "%PORT%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "test_size": "%SIZE%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "file_size_downloaded": "!TRANSFERRED_CLEAN!",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "data_units": "!TRANSFER_UNIT!",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "parallel_connections": "%PARALLEL_CONNECTIONS%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "max_parallel_called": "%PARALLEL_CONNECTIONS%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "speed_mbps": !SPEED_MBPS_PRECISE!,>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "speed_units": "Mbps",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "speed_raw_mbytes_sec": "!SPEED_NUMERIC!",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "speed_raw_units": "MBytes/sec",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "total_data_transferred": "!TRANSFERRED_CLEAN!",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "test_type": "%TEST_MODE%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "timestamp": "%CLEAN_TIMESTAMP%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "date": "%CLEAN_DATE%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "time": "%CLEAN_TIME%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "logfile": "%CURRENT_LOGFILE%",>> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo   "status": "%TEST_STATUS%">> "%TESTDIR%\_entry_%TEST_MODE%.json"
    echo }>> "%TESTDIR%\_entry_%TEST_MODE%.json"

    echo JSON entry created at: %TESTDIR%\_entry_%TEST_MODE%.json

    :: === Append into per-test results.json ===
    echo Appending to results.json...
    if exist "%TESTDIR%\_entry_%TEST_MODE%.json" (
        call :appendJson "%JSONFILE%" "%TESTDIR%\_entry_%TEST_MODE%.json" 2>nul
        echo Results appended to: %JSONFILE%
    ) else (
        echo ERROR: Entry file not found for appending
    )
    
    :: === Append into summary results_summary.json ===
    echo Appending to summary...
    if exist "%TESTDIR%\_entry_%TEST_MODE%.json" (
        call :appendJson "%SUMMARYFILE%" "%TESTDIR%\_entry_%TEST_MODE%.json" 2>nul
        echo Summary appended to: %SUMMARYFILE%
    )
    
    :: === Append into global summary (all tests) ===
    echo Appending to global summary...
    if exist "%TESTDIR%\_entry_%TEST_MODE%.json" (
        call :appendJson "%GLOBALSUMMARY%" "%TESTDIR%\_entry_%TEST_MODE%.json" 2>nul
        echo Global summary appended to: %GLOBALSUMMARY%
    )

    if exist "%TESTDIR%\_entry_%TEST_MODE%.json" (
        del "%TESTDIR%\_entry_%TEST_MODE%.json" 2>nul
    )
    echo.
    echo [SUCCESS] %TEST_MODE% test complete and results saved
    echo %TEST_MODE% results saved in: %CURRENT_LOGFILE%
    echo Maximum %TEST_MODE% Speed: !SPEED_MBPS_PRECISE! Mbps (!SPEED_NUMERIC! MBytes/sec)
    echo Data Transferred: !TRANSFERRED_CLEAN! !TRANSFER_UNIT!
) else (
    echo.
    echo [ERROR] %TEST_MODE% test failed - results not saved to JSON files
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
