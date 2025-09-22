@echo off
setlocal enabledelayedexpansion

echo Testing JSON creation...

set TESTNAME=test-simple
set LOCAL_IP=10.10.3.70
set IP=34.47.164.139
set PORT=80
set SIZE=10M
set PARALLEL_CONNECTIONS=16
set TEST_MODE=download
set TEST_STATUS=success
set SPEED_MBPS_PRECISE=270.4
set SPEED_NUMERIC=33.8
set TRANSFERRED_CLEAN=1000
set TRANSFER_UNIT=MBytes
set LOG_LOCAL_IP=10.10.3.70
set CURRENT_LOGFILE=test.log
set CLEAN_DATE=2024-09-22
set CLEAN_TIME=15-30-00
set CLEAN_TIMESTAMP=2024-09-22_15-30-00

set TESTDIR=c:\Users\senth\Downloads\iperf3.1.1_32\results\test-simple
if not exist "%TESTDIR%" mkdir "%TESTDIR%"

echo Creating JSON...
echo {> "%TESTDIR%\test.json"
echo   "test_name": "%TESTNAME%",>> "%TESTDIR%\test.json"
echo   "local_ip": "%LOG_LOCAL_IP%",>> "%TESTDIR%\test.json"
echo   "local_ip_system": "%LOCAL_IP%",>> "%TESTDIR%\test.json"
echo   "server_ip": "%IP%",>> "%TESTDIR%\test.json"
echo   "server_port": "%PORT%",>> "%TESTDIR%\test.json"
echo   "test_size": "%SIZE%",>> "%TESTDIR%\test.json"
echo   "speed_mbps": %SPEED_MBPS_PRECISE%,>> "%TESTDIR%\test.json"
echo   "status": "%TEST_STATUS%">> "%TESTDIR%\test.json"
echo }>> "%TESTDIR%\test.json"

echo JSON created successfully at: %TESTDIR%\test.json
type "%TESTDIR%\test.json"