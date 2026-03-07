import Cocoa
import Foundation
import Darwin

enum TestInterval: TimeInterval, CaseIterable {
    case fiveMinutes   = 300
    case tenMinutes    = 600
    case thirtyMinutes = 1800
    case oneHour       = 3600

    var title: String {
        switch self {
        case .fiveMinutes:   return "Every 5 minutes"
        case .tenMinutes:    return "Every 10 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour:       return "Every hour"
        }
    }
}

struct SpeedTestResult {
    let downloadSpeed: Double  // Mbps
    let uploadSpeed: Double    // Mbps
    let ping: Double           // ms
    let timestamp: Date
}

struct NetworkUsage {
    let downloadSpeed: Double  // B/s
    let uploadSpeed: Double    // B/s
    let timestamp: Date
}

struct PublicIP {
    let ipv4: String
    let ipv6: String
    let lastUpdated: Date
}

class SpeedTestMonitor: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var speedTestTimer: DispatchSourceTimer?
    private var networkUsageTimer: DispatchSourceTimer?
    private var networkChangeTimer: DispatchSourceTimer?
    // Dispatch-based toggle timer (more reliable)
    private var toggleDispatchSource: DispatchSourceTimer?
    private var lastResult: SpeedTestResult?
    private var currentUsage: NetworkUsage?
    private var publicIP: PublicIP?
    private var testInterval: TestInterval = .fiveMinutes
    private var showingSpeedTest = false // Toggle state
    
    // Network change detection
    private var lastNetworkInterface = ""
    private var lastNetworkIP = ""
    
    // Network usage tracking
    private var lastBytesReceived: Int64 = 0
    private var lastBytesSent: Int64 = 0
    private var lastNetworkUpdateTime: Date = Date()
    
    // Menu items
    private var intervalMenuItems: [TestInterval: NSMenuItem] = [:]
    private var testNowItem: NSMenuItem!
    private var lastTestItem: NSMenuItem!
    private var currentUsageItem: NSMenuItem!
    private var ipv4Item: NSMenuItem!
    private var ipv6Item: NSMenuItem!
    private var refreshIPItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Menu bar app
        NSApp.activate(ignoringOtherApps: true)
        
        setupStatusBar()
        setupMenu()
        startMonitoring()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Ready"
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Test now option
        testNowItem = NSMenuItem(title: "Test Now", action: #selector(runSpeedTest), keyEquivalent: "")
        testNowItem.target = self
        menu.addItem(testNowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Current network usage
        currentUsageItem = NSMenuItem(title: "Current: ↓0.0B ↑0.0B", action: nil, keyEquivalent: "")
        menu.addItem(currentUsageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Public IP section
        ipv4Item = NSMenuItem(title: "IPv4: Detecting...", action: #selector(copyIPv4), keyEquivalent: "")
        ipv4Item.target = self
        menu.addItem(ipv4Item)
        
        ipv6Item = NSMenuItem(title: "IPv6: Detecting...", action: #selector(copyIPv6), keyEquivalent: "")
        ipv6Item.target = self
        menu.addItem(ipv6Item)
        
        refreshIPItem = NSMenuItem(title: "Refresh IP", action: #selector(refreshPublicIP), keyEquivalent: "")
        refreshIPItem.target = self
        menu.addItem(refreshIPItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Interval options
        let intervalMenu = NSMenu()
        
        let intervalActions: [(TestInterval, Selector)] = [
            (.fiveMinutes,   #selector(setInterval5)),
            (.tenMinutes,    #selector(setInterval10)),
            (.thirtyMinutes, #selector(setInterval30)),
            (.oneHour,       #selector(setInterval60))
        ]
        for (interval, action) in intervalActions {
            let item = NSMenuItem(title: interval.title, action: action, keyEquivalent: "")
            item.target = self
            intervalMenu.addItem(item)
            intervalMenuItems[interval] = item
        }
        
        let intervalItem = NSMenuItem(title: "Test Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Last test result
        lastTestItem = NSMenuItem(title: "Last test: Never", action: nil, keyEquivalent: "")
        menu.addItem(lastTestItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        updateIntervalMenu()
    }
    
    private func makeDispatchTimer(interval: TimeInterval, block: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { block() }
        timer.resume()
        return timer
    }

    private func startMonitoring() {
        // Start network usage monitoring (every 1 second)
        networkUsageTimer = makeDispatchTimer(interval: 1.0) { [weak self] in
            self?.updateNetworkUsage()
        }
        
        // Start network change detection (every 5 seconds)
        networkChangeTimer = makeDispatchTimer(interval: 5.0) { [weak self] in
            self?.checkNetworkChange()
        }
        
        // Initialize network state
        initializeNetworkState()
        
        // Get public IP on startup
        DispatchQueue.global(qos: .utility).async {
            self.updatePublicIP()
        }
        
        // Run initial speed test immediately on start
        runSpeedTest()
        showingSpeedTest = true // Start in speed test mode
        
        // Set up recurring speed tests
        speedTestTimer = makeDispatchTimer(interval: testInterval.rawValue) { [weak self] in
            self?.runSpeedTest()
        }
        
        // Start display toggle (5 seconds each)
        toggleDispatchSource = makeDispatchTimer(interval: 5.0) { [weak self] in
            self?.toggleDisplay()
        }
    }
    
    @objc private func runSpeedTest() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.performSpeedTest()
        }
    }
    
    private func updateNetworkUsage() {
        let iface = (lastNetworkInterface.isEmpty || lastNetworkInterface == "unknown") ? "en0" : lastNetworkInterface
        guard let (bytesReceived, bytesSent) = getByteCounts(for: iface) else { return }

        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastNetworkUpdateTime)

        if timeInterval > 0 && lastBytesReceived > 0 {
            let downloadSpeed = max(0, Double(bytesReceived - lastBytesReceived) / timeInterval)
            let uploadSpeed   = max(0, Double(bytesSent   - lastBytesSent)   / timeInterval)

            let usage = NetworkUsage(downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed, timestamp: currentTime)
            currentUsage = usage

            let down = formatNetworkSpeed(speed: downloadSpeed)
            let up   = formatNetworkSpeed(speed: uploadSpeed)
            currentUsageItem.title = "Current: \u{2193}\(down) \u{2191}\(up)"
            if !showingSpeedTest {
                statusItem.button?.title = "\u{2193}\(down) \u{2191}\(up)"
            }
        }

        lastBytesReceived     = bytesReceived
        lastBytesSent         = bytesSent
        lastNetworkUpdateTime = currentTime
    }

    private func getByteCounts(for interfaceName: String) -> (received: Int64, sent: Int64)? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else { return nil }
        defer { freeifaddrs(ifap) }

        var received: Int64 = 0
        var sent: Int64 = 0
        var found = false

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ifa = cursor {
            let name = String(cString: ifa.pointee.ifa_name)
            if name == interfaceName, ifa.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                if let data = ifa.pointee.ifa_data {
                    let stats = data.load(as: if_data.self)
                    received = Int64(stats.ifi_ibytes)
                    sent     = Int64(stats.ifi_obytes)
                    found    = true
                }
            }
            cursor = ifa.pointee.ifa_next
        }

        return found ? (received, sent) : nil
    }

    private func formatNetworkSpeed(speed: Double) -> String {
        if speed >= 1024 * 1024 {
            return String(format: "%.1fM", speed / (1024 * 1024))
        } else if speed >= 1024 {
            return String(format: "%.1fK", speed / 1024)
        } else {
            return String(format: "%.0fB", speed)
        }
    }
    
    @objc private func refreshPublicIP() {
        DispatchQueue.global(qos: .utility).async {
            self.updatePublicIP()
        }
    }
    
    private func initializeNetworkState() {
        let interface = getCurrentNetworkInterface()
        lastNetworkInterface = interface
        lastNetworkIP = getCurrentNetworkIP(for: interface)
        if let (recv, sent) = getByteCounts(for: interface) {
            lastBytesReceived = recv
            lastBytesSent     = sent
        }
    }
    
    private func checkNetworkChange() {
        let currentInterface = getCurrentNetworkInterface()
        let currentIP = getCurrentNetworkIP(for: currentInterface)
        
        // Check if interface or IP changed
        if currentInterface != lastNetworkInterface || currentIP != lastNetworkIP {
            print("Network changed from \(lastNetworkInterface) (\(lastNetworkIP)) to \(currentInterface) (\(currentIP))")
            
            // Update stored values
            lastNetworkInterface = currentInterface
            lastNetworkIP = currentIP
            
            // Trigger speed test on network change
            DispatchQueue.main.async {
                print("Triggering speed test due to network change")
                self.runSpeedTest()
            }
            
            // Update public IP since network changed
            DispatchQueue.global(qos: .utility).async {
                self.updatePublicIP()
            }
        }
    }
    
    private func getCurrentNetworkInterface() -> String {
        do {
            let task = Process()
            task.launchPath = "/sbin/route"
            task.arguments = ["get", "default"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try task.run()
            task.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("interface:") {
                    let iface = trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
                    if !iface.isEmpty { return iface }
                }
            }
        } catch {
            // Process failed, fall back to default
        }
        return "unknown"
    }
    
    private func getCurrentNetworkIP(for interface: String? = nil) -> String {
        let iface = interface ?? getCurrentNetworkInterface()
        if iface == "unknown" {
            return "no_ip"
        }
        
        do {
            let task = Process()
            task.launchPath = "/usr/sbin/ifconfig"
            task.arguments = [iface]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try task.run()
            task.waitUntilExit()
            
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            
            for line in output.components(separatedBy: "\n") {
                if line.contains("inet ") && !line.contains("inet 127.0.0.1") {
                    let parts = line.components(separatedBy: .whitespaces)
                    if let idx = parts.firstIndex(of: "inet"), idx + 1 < parts.count {
                        return parts[idx + 1]
                    }
                }
            }
        } catch {
            // Process failed, fall back to default
        }
        return "no_ip"
    }
    
    private func updatePublicIP() {
        let ipv4 = getPublicIPv4()
        let ipv6 = getPublicIPv6()
        
        let ip = PublicIP(
            ipv4: ipv4,
            ipv6: ipv6,
            lastUpdated: Date()
        )
        
        publicIP = ip
        
        DispatchQueue.main.async {
            self.ipv4Item.title = "IPv4: \(ipv4)  (click to copy)"
            self.ipv6Item.title = "IPv6: \(ipv6)  (click to copy)"
        }
    }

    @objc private func copyIPv4() {
        guard let ip = publicIP?.ipv4 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        ipv4Item.title = "IPv4: \(ip)  ✓ Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.ipv4Item.title = "IPv4: \(ip)  (click to copy)"
        }
    }

    @objc private func copyIPv6() {
        guard let ip = publicIP?.ipv6 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        ipv6Item.title = "IPv6: \(ip)  ✓ Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.ipv6Item.title = "IPv6: \(ip)  (click to copy)"
        }
    }
    
    private func fetchPublicIP(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Unknown" }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = "Unknown"
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                result = ip
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return result
    }
    
    private func getPublicIPv4() -> String {
        fetchPublicIP(from: "https://api.ipify.org")
    }
    
    private func getPublicIPv6() -> String {
        fetchPublicIP(from: "https://api64.ipify.org")
    }
    
    private func performSpeedTest() {
        DispatchQueue.main.async {
            self.statusItem.button?.title = "Testing..."
            self.testNowItem.title = "Testing..."
        }
        
        // Test ping first
        let ping = measurePing()
        
        // Test download speed using fast.com API
        let downloadSpeed = measureDownloadSpeed()
        
        // Test upload speed (simple test)
        let uploadSpeed = measureUploadSpeed()
        
        let result = SpeedTestResult(
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            ping: ping,
            timestamp: Date()
        )
        
        lastResult = result
        
        DispatchQueue.main.async {
            self.updateLastTestItem(result: result)
            self.testNowItem.title = "Test Now"
            
            // Show speed test result immediately if it's time to show speed
            if self.showingSpeedTest {
                self.showSpeedTestResult(result: result)
            }
        }
    }
    
    private func showSpeedTestResult(result: SpeedTestResult) {
        let pingText = String(format: "%.0f", result.ping)
        let downloadText = String(format: "%.1f", result.downloadSpeed)
        let uploadText = String(format: "%.1f", result.uploadSpeed)
        
        statusItem.button?.title = "\(pingText)ms ↓\(downloadText) ↑\(uploadText)"
    }
    
    private func toggleDisplay() {
        showingSpeedTest.toggle()
        
        if showingSpeedTest {
            if let result = lastResult {
                showSpeedTestResult(result: result)
            } else {
                statusItem.button?.title = "No test yet"
            }
        } else {
            if let usage = currentUsage {
                let down = formatNetworkSpeed(speed: usage.downloadSpeed)
                let up   = formatNetworkSpeed(speed: usage.uploadSpeed)
                statusItem.button?.title = "\u{2193}\(down) \u{2191}\(up)"
            } else {
                statusItem.button?.title = "\u{2193}-- \u{2191}--"
            }
        }
    }
    
    private func measurePing() -> Double {
        let task = Process()
        task.launchPath = "/sbin/ping"
        task.arguments = ["-c", "3", "8.8.8.8"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Parse ping time from output
        if let range = output.range(of: "time=") {
            let substring = output[range.upperBound...]
            if let timeEnd = substring.range(of: " ") {
                let timeString = String(substring[..<timeEnd.lowerBound])
                return Double(timeString) ?? 0
            }
        }
        
        return 0
    }
    
    private func measureDownloadSpeed() -> Double {
        // Use multiple speed test servers for better accuracy
        let testUrls = [
            "https://speed.cloudflare.com/__down?bytes=25000000", // 25MB
            "https://proof.ovh.net/files/100Mb.dat", // 100MB
            "https://speedtest.tele2.net/100MB.zip" // 100MB
        ]
        
        for urlString in testUrls {
            guard let url = URL(string: urlString) else { continue }
            
            let speed = measureDownloadSpeedFromUrl(url)
            if speed > 0 {
                return speed
            }
        }
        
        return 0
    }
    
    private func measureDownloadSpeedFromUrl(_ url: URL) -> Double {
        let startTime = Date()
        var totalBytes: Int64 = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, error == nil {
                totalBytes = Int64(data.count)
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        let endTime = Date()
        let timeInterval = endTime.timeIntervalSince(startTime)
        
        if timeInterval > 0 && totalBytes > 0 {
            let bitsPerSecond = Double(totalBytes * 8) / timeInterval
            return bitsPerSecond / 1_000_000 // Convert to Mbps
        }
        
        return 0
    }
    
    private func measureUploadSpeed() -> Double {
        let endpoints = [
            "https://speed.cloudflare.com/__up",
            "https://httpbin.org/post"
        ]

        // 5MB payload — large enough that connection overhead (~100–300ms) is
        // a small fraction of total transfer time even on slower connections.
        let testData = Data(repeating: 0x55, count: 5 * 1024 * 1024)

        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.httpBody = testData
            request.timeoutInterval = 30

            let startTime = Date()
            let semaphore = DispatchSemaphore(value: 0)
            var statusCode = 0

            URLSession.shared.dataTask(with: request) { _, response, error in
                if error == nil {
                    statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                }
                semaphore.signal()
            }.resume()

            semaphore.wait()
            let timeInterval = Date().timeIntervalSince(startTime)

            if (200...299).contains(statusCode) && timeInterval > 0 {
                let bitsPerSecond = Double(testData.count * 8) / timeInterval
                return bitsPerSecond / 1_000_000 // Convert to Mbps
            }
        }

        return 0
    }
    
    private func updateLastTestItem(result: SpeedTestResult) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let title = String(format: "Last test: %@ (↓%.1f ↑%.1f %.0fms)",
                          formatter.string(from: result.timestamp),
                          result.downloadSpeed,
                          result.uploadSpeed,
                          result.ping)
        lastTestItem.title = title
    }
    
    // Interval setters
    @objc private func setInterval5()  { setInterval(.fiveMinutes) }
    @objc private func setInterval10() { setInterval(.tenMinutes) }
    @objc private func setInterval30() { setInterval(.thirtyMinutes) }
    @objc private func setInterval60() { setInterval(.oneHour) }
    
    private func setInterval(_ interval: TestInterval) {
        testInterval = interval
        
        speedTestTimer?.cancel()
        speedTestTimer = makeDispatchTimer(interval: testInterval.rawValue) { [weak self] in
            self?.runSpeedTest()
        }
        
        updateIntervalMenu()
    }
    
    private func updateIntervalMenu() {
        for (interval, item) in intervalMenuItems {
            item.state = interval == testInterval ? .on : .off
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        speedTestTimer?.cancel()
        networkUsageTimer?.cancel()
        toggleDispatchSource?.cancel()
        networkChangeTimer?.cancel()
    }
}

// Main
let app = NSApplication.shared
let delegate = SpeedTestMonitor()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
