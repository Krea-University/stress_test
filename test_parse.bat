@echo off
setlocal enabledelayedexpansion

set LOGFILE=%1

echo Testing parsing logic on: %LOGFILE%
echo.

:: Extract speed information from log file (v3.1.1 compatible)
set MAX_SPEED=Unknown
set TOTAL_TRANSFERRED=Unknown

if exist "%LOGFILE%" (
    echo Found log file
    :: Get final summary data from the [SUM] line - get the last occurrence
    :: Line format: [SUM]   0.00-27.33  sec  1.00 GBytes  37.5 MBytes/sec                  sender
    :: So tokens are: 1=[SUM] 2=interval 3=sec 4=amount 5=unit 6=speed 7=speed_unit 8=sender
    for /f "tokens=4,5,6,7" %%a in ('findstr /c:"[SUM]" "%LOGFILE%" 2^>nul ^| findstr /c:"sender"') do (
        set TOTAL_TRANSFERRED=%%a
        set TRANSFER_UNIT=%%b
        set MAX_SPEED=%%c
        set SPEED_UNIT=%%d
        echo Found sender line: Transfer=!TOTAL_TRANSFERRED! !TRANSFER_UNIT!, Speed=!MAX_SPEED! !SPEED_UNIT!
    )
    
    :: If no sender line found, try receiver line (for downloads in reverse mode)  
    if "!MAX_SPEED!"=="Unknown" (
        echo Trying receiver line...
        for /f "tokens=4,5,6,7" %%a in ('findstr /c:"[SUM]" "%LOGFILE%" 2^>nul ^| findstr /c:"receiver"') do (
            set TOTAL_TRANSFERRED=%%a
            set TRANSFER_UNIT=%%b
            set MAX_SPEED=%%c
            set SPEED_UNIT=%%d
            echo Found receiver line: Transfer=!TOTAL_TRANSFERRED! !TRANSFER_UNIT!, Speed=!MAX_SPEED! !SPEED_UNIT!
        )
    )
) else (
    echo Log file not found!
)

echo.
echo Final results:
echo MAX_SPEED=!MAX_SPEED!
echo TOTAL_TRANSFERRED=!TOTAL_TRANSFERRED!
echo TRANSFER_UNIT=!TRANSFER_UNIT!
echo SPEED_UNIT=!SPEED_UNIT!

pause