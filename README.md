# Network Monitor - macOS Menu Bar App

A lightweight macOS menu bar application that displays real-time download and upload speeds.

## Features

- Real-time network speed monitoring in the macOS menu bar
- Displays download (↓) and upload (↑) speeds
- Automatic unit conversion (B/s, KB/s, MB/s)
- Clean, minimal interface
- Runs as a background application (no dock icon)
- Auto-detects active network interface (en0-en4)

## Requirements

- macOS 10.12 or later
- Xcode Command Line Tools (for Swift compiler)
- Network monitoring permissions

## Installation

1. Clone or download this repository
2. Make the scripts executable:
   ```bash
   chmod +x build.sh start.sh
   ```
3. Build the application:
   ```bash
   ./build.sh
   ```

## Usage

### Option 1: Run in background (recommended)
```bash
./start.sh
```
This will start the app in the background and you can close the terminal.

### Option 2: Run in foreground
```bash
./NetworkMonitor
```
Keep the terminal open while using.

## Stopping the Application

To stop the background process:
```bash
pkill -f NetworkMonitor
```

Or use Activity Monitor to find and quit "NetworkMonitor".

## What You'll See

Once launched, the app will appear in your macOS menu bar showing:
- **Download speed** (↓): Current download rate
- **Upload speed** (↑): Current upload rate

The speeds update every second and automatically scale between:
- **B/s** for bytes per second
- **K/s** for kilobytes per second  
- **M/s** for megabytes per second

## Troubleshooting

- If speeds show as 0.0B, the app couldn't find an active network interface
- The app automatically tries en0, en1, en2, en3, en4 interfaces
- Make sure you're connected to a network
- To quit the app, use `pkill -f NetworkMonitor` or Activity Monitor

## Technical Details

- Built with Swift and Cocoa
- Uses `netstat -b -I [interface]` to get network statistics
- Updates every second for real-time monitoring
- Runs as a background accessory application
- Auto-detects the first available network interface
