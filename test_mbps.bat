@echo off
setlocal enabledelayedexpansion

:: Simulate the enhanced Mbps calculation
set MAX_SPEED=37.5
set SPEED_NUMERIC=37.5

echo Testing enhanced Mbps calculation:
echo Input: !SPEED_NUMERIC! MBytes/sec

:: For integer value (for compatibility)
for /f "delims=." %%j in ("!SPEED_NUMERIC!") do (
    set /a "SPEED_MBPS=%%j * 8" 2>nul || set "SPEED_MBPS=0"
)

:: For precise decimal calculation using PowerShell
for /f %%k in ('powershell -command "[math]::Round(!SPEED_NUMERIC! * 8, 2)"') do (
    set "SPEED_MBPS_PRECISE=%%k"
)

echo.
echo Results:
echo - Integer calculation: !SPEED_MBPS! Mbps
echo - Precise calculation: !SPEED_MBPS_PRECISE! Mbps
echo - Units: Megabits per second (Mbps)

echo.
echo JSON Format Example:
echo {
echo   "speed_mbps": !SPEED_MBPS_PRECISE!,
echo   "speed_units": "Mbps",
echo   "speed_raw_mbytes_sec": "!SPEED_NUMERIC!",
echo   "speed_raw_units": "MBytes/sec"
echo }

pause