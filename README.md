# FusionNet Stat

![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

A lightweight macOS menu bar application that displays real-time network usage and performs periodic speed tests.

## Features

- 🌐 **Real-time usage** — Live ↓ download and ↑ upload speeds updated every second
- ⚡ **Speed tests** — Measures actual internet speed (Mbps) and ping in ms
- 🔄 **Alternating display** — Toggles between live usage and speed test results every 5 seconds
- 📍 **Public IP** — Shows your IPv4 and IPv6 addresses (click to copy)
- 🚀 **Auto speed test on network change** — Automatically tests when you switch WiFi
- ⏱️ **Configurable intervals** — Run speed tests every 5, 10, 30, or 60 minutes
- 🔐 **Auto-starts on login** — Always running in the background via LaunchAgent
- 📋 **Click-to-copy IP addresses** — Easy copying of IPv4/IPv6 from menu

## Installation

### Option 1: DMG Installer (Recommended)

1. Download the latest [FusionNet Stat 1.0.dmg](https://github.com/yourusername/fusion-net-stat/releases)
2. Open the DMG file
3. Double-click `Install FusionNet Stat.command`
4. Enter your password if prompted
5. The app will install and start automatically

### Option 2: Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/fusion-net-stat.git
cd fusion-net-stat

# Install Xcode Command Line Tools if needed
xcode-select --install

# Run the installer
chmod +x install.sh
./install.sh
```

## Requirements

- macOS 10.15 or later
- Xcode Command Line Tools (installed automatically by DMG installer)

---

## What You'll See in the Menu Bar

The display alternates every 5 seconds:

| Mode | Example |
|------|---------|
| **Live usage** | `↓50.2K ↑5.1B` |
| **Speed test** | `12ms ↓148.5 ↑22.3` |

---

## Right-Click Menu

| Item | Description |
|------|-------------|
| **Test Now** | Run a speed test immediately |
| **Current: ↓X ↑X** | Live network usage |
| **IPv4 / IPv6** | Your public IP addresses |
| **Refresh IP** | Re-fetch your public IPs |
| **Test Interval** | Set how often speed tests run |
| **Last test** | Timestamp and results of last test |
| **Quit** | Stop the app |

---

## Uninstall

```bash
./uninstall.sh
```

This stops the app and removes the auto-start entry. No other files are modified.

---

## Troubleshooting

- **Speed test stuck on "Testing..."** — wait up to 30 seconds; it downloads a test file to measure speed
- **Shows "Ready" with no data** — make sure you're connected to a network
- **Check logs** — `cat /tmp/SpeedTestMonitor.log`

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/fusion-net-stat.git
cd fusion-net-stat

# Build the app
swiftc -o SpeedTestMonitor SpeedTestMonitor.swift -framework Cocoa -framework Foundation

# Run locally
./SpeedTestMonitor
```

### Creating a DMG Installer

```bash
# Create distributable DMG
./create-installer.sh
```

## Architecture

- **Language**: Swift 5
- **Frameworks**: Cocoa, Foundation, Darwin
- **Key Components**:
  - `SpeedTestMonitor.swift`: Main application logic with network monitoring and speed testing
  - `install.sh`: Installation script with LaunchAgent setup
  - `create-installer.sh`: DMG creator for distribution
  - Uses `getifaddrs` for reliable network statistics
  - `DispatchSourceTimer` for reliable timing even during menu interaction

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas for Contribution
- Graphical network usage history
- Support for multiple network interfaces
- Customizable speed test servers
- Dark mode support
- Bandwidth usage caps with alerts

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter issues:

1. Check existing [Issues](https://github.com/yourusername/fusion-net-stat/issues)
2. Create a new issue with your macOS version and detailed description
3. Include logs from `/tmp/SpeedTestMonitor.log` if available

## Acknowledgments

- Cloudflare for reliable speed test endpoints
- httpbin.org for upload testing fallback
- macOS `getifaddrs` documentation and examples
