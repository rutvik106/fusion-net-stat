# FusionNet Stat — macOS Menu Bar App

A lightweight macOS menu bar app that shows **real-time network usage** and **internet speed test results** — always visible, no digging through Settings.

---

## Features

- **Real-time usage** — live ↓ download and ↑ upload speeds updated every second
- **Speed tests** — measures actual internet speed (Mbps), ping in ms
- **Alternating display** — toggles between live usage and speed test results every 5 seconds
- **Public IP** — shows your IPv4 and IPv6 addresses, refreshable on demand
- **Auto speed test on network change** — automatically tests when you switch WiFi or hotspot
- **Configurable intervals** — run speed tests every 5, 10, 30, or 60 minutes
- **Auto-starts on login** — always running in the background
- **No dock icon** — lives quietly in the menu bar

---

## Requirements

- macOS 10.14 or later
- Xcode Command Line Tools

---

## Installation

### Step 1 — Install Xcode Command Line Tools (one-time)

Open Terminal and run:
```bash
xcode-select --install
```
A dialog will appear — click **Install** and wait for it to finish.

### Step 2 — Download the project

Download or clone this repository to your Mac, then open Terminal and navigate to the folder:
```bash
cd /path/to/windsurf-project
```

### Step 3 — Run the installer
```bash
chmod +x install.sh
./install.sh
```

That's it! The app will appear in your menu bar and will auto-start on every login.

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

---

## Tech Stack

- Swift + Cocoa + Foundation
- `netstat` for real-time network usage
- Cloudflare / OVH speed test files for download measurement
- `api.ipify.org` for public IP detection
- macOS Launch Agents for auto-start
