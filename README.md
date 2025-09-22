# iperf3 Network Speed Test Tool

A comprehensive network speed testing tool using iperf3 with animated progress display and detailed result tracking.

## 📁 Project Structure

```
iperf3.1.1_32/
├── results/                           # All test results organized here
│   ├── location1/                     # Test results for location1
│   │   ├── location1_2025-09-22_12-30-15_report.txt
│   │   ├── results.json              # Location-specific results
│   │   └── results_summary.json      # Location summary
│   ├── location2/                     # Test results for location2
│   │   ├── location2_2025-09-22_13-45-30_report.txt
│   │   ├── results.json
│   │   └── results_summary.json
│   └── all_tests_summary.json        # Global summary of ALL tests
├── iperf_test.bat                     # Main testing script
├── organize_results.bat               # Script to organize existing results
├── iperf3.exe                        # iperf3 executable
└── README.md                          # This file
```

## 🚀 Features

### Live Progress Animation
- **Animated progress bar**: Visual progress from 1% to 100%
- **Real-time bandwidth display**: Shows current download speed
- **Connection status**: Displays parallel stream count
- **Server information**: Shows target IP and port

### Download Speed Testing
- **Reverse mode testing**: Tests download speeds (server→client)
- **Multiple parallel connections**: Configurable (default: 32 streams)
- **Large file transfers**: Supports up to 100GB transfers
- **Timeout handling**: 5-minute timeout with early connection detection

### Comprehensive Results
- **Raw logs**: Complete iperf3 output with all technical details
- **JSON summaries**: Structured data for easy analysis
- **Global tracking**: All tests tracked in single summary file
- **Speed extraction**: Maximum speeds and data transfer amounts

## 📊 Result Files

### 1. Raw Test Reports
- **Location**: `results/{location_name}/{location_name}_{timestamp}_report.txt`
- **Content**: Complete iperf3 output with connection details and bandwidth measurements

### 2. Location Summary
- **Location**: `results/{location_name}/results_summary.json`
- **Content**: All tests for specific location with speeds, timestamps, and status

### 3. Global Summary
- **Location**: `results/all_tests_summary.json`
- **Content**: Complete history of ALL tests across ALL locations

## 🛠️ Usage

### Running a Test
1. Run `iperf_test.bat`
2. Enter location name when prompted
3. Enter file size (default: 100G)
4. Watch the animated progress display
5. Review results and summaries

### Organizing Existing Results
1. Run `organize_results.bat` to move existing test folders into `results/`
2. This will organize any existing test data into the new structure

## ⚙️ Configuration

Edit the configuration section in `iperf_test.bat`:

```batch
:: === Configurations ===
set IP=34.180.16.45              # Target server IP
set PORT=80                      # Target server port
set PARALLEL_CONNECTIONS=32      # Number of parallel streams
set TIMEOUT=300                  # Test timeout in seconds
```

## 📈 Example Output

```
┌────────────────────────────────────────────────────────┐
│                    Download Progress                   │
└────────────────────────────────────────────────────────┘

[████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░] 67%
Current Speed: 485 Mbps
Connections: 32 parallel streams
Server: 34.180.16.45:80
```

## 📋 JSON Summary Example

```json
{
  "test_name": "office_location",
  "server_ip": "34.180.16.45",
  "server_port": "80",
  "test_size": "10G",
  "parallel_connections": "32",
  "max_download_speed_mbps": "502",
  "total_data_transferred": "2.5 GBytes",
  "test_type": "download",
  "timestamp": "2025-09-22_14-30-15",
  "status": "success",
  "timeout_seconds": "300"
}
```

## 🔧 Troubleshooting

### Common Issues
- **Control socket errors**: Script handles these automatically and saves partial results
- **Path issues**: All results now organized in `results/` folder
- **Timeout errors**: Configurable timeout prevents hanging

### Error Handling
- **Partial success detection**: Saves results even if connection drops early
- **Speed extraction**: Gets maximum speeds achieved during test
- **Status tracking**: Clear success/failure/partial status in summaries

## 📞 Support

For issues or improvements, please check the test logs in the `results/` folder and review the JSON summaries for detailed information about test performance.