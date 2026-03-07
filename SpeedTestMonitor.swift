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
    private var speedTestTimer: Timer?
    private var networkUsageTimer: Timer?
    private var displayToggleTimer: Timer?
    private var networkChangeTimer: Timer?
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
        ipv4Item = NSMenuItem(title: "IPv4: Detecting...", action: nil, keyEquivalent: "")
        menu.addItem(ipv4Item)
        
        ipv6Item = NSMenuItem(title: "IPv6: Detecting...", action: nil, keyEquivalent: "")
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
    
    private func startMonitoring() {
        // Start network usage monitoring (every 1 second)
        networkUsageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNetworkUsage()
        }
        
        // Start network change detection (every 5 seconds)
        networkChangeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkNetworkChange()
        }
        
        // Initialize network state
        initializeNetworkState()
        
        // Get public IP on startup
        DispatchQueue.global(qos: .utility).async {
            self.updatePublicIP()
        }
        
        // Run initial speed test after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.runSpeedTest()
        }
        
        // Set up recurring speed tests
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: testInterval.rawValue, repeats: true) { [weak self] _ in
            self?.runSpeedTest()
        }
        
        // Start display toggle (5 seconds each)
        displayToggleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.toggleDisplay()
        }
    }
    
    @objc private func runSpeedTest() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.performSpeedTest()
        }
    }
    
    private func updateNetworkUsage() {
        let iface = lastNetworkInterface.isEmpty ? "en0" : lastNetworkInterface
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readAndPublishNetworkUsage(for: iface)
        }
    }

    private func readAndPublishNetworkUsage(for iface: String) {
        guard let (bytesReceived, bytesSent) = getByteCounts(for: iface) else { return }

        let currentTime = Date()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let timeInterval = currentTime.timeIntervalSince(self.lastNetworkUpdateTime)

            if timeInterval > 0 && self.lastBytesReceived > 0 {
                let downloadSpeed = max(0, Double(bytesReceived - self.lastBytesReceived) / timeInterval)
                let uploadSpeed   = max(0, Double(bytesSent   - self.lastBytesSent)   / timeInterval)

                let usage = NetworkUsage(downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed, timestamp: currentTime)
                self.currentUsage = usage
                self.updateCurrentUsageItem(usage: usage)
            }

            self.lastBytesReceived     = bytesReceived
            self.lastBytesSent         = bytesSent
            self.lastNetworkUpdateTime = currentTime
        }
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
    
    private func updateCurrentUsageItem(usage: NetworkUsage) {
        let downloadText = formatNetworkSpeed(speed: usage.downloadSpeed)
        let uploadText = formatNetworkSpeed(speed: usage.uploadSpeed)
        
        DispatchQueue.main.async {
            self.currentUsageItem.title = "Current: ↓\(downloadText) ↑\(uploadText)"
            
            // Update menu bar with current usage when not showing speed test
            if !self.showingSpeedTest {
                self.statusItem.button?.title = "↓\(downloadText) ↑\(uploadText)"
            }
        }
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
        let task = Process()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-rn", "-f", "inet"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Look for default route interface
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("default") || line.hasPrefix("0.0.0.0") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 6 {
                    return components[5] // Interface name
                }
            }
        }
        
        return "unknown"
    }
    
    private func getCurrentNetworkIP(for interface: String? = nil) -> String {
        let iface = interface ?? getCurrentNetworkInterface()
        if iface == "unknown" {
            return "no_ip"
        }
        
        let task = Process()
        task.launchPath = "/usr/sbin/ifconfig"
        task.arguments = [iface]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("inet ") && !line.contains("inet 127.0.0.1") {
                let parts = line.components(separatedBy: .whitespaces)
                if let idx = parts.firstIndex(of: "inet"), idx + 1 < parts.count {
                    return parts[idx + 1]
                }
            }
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
            self.ipv4Item.title = "IPv4: \(ipv4)"
            self.ipv6Item.title = "IPv6: \(ipv6)"
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
                statusItem.button?.title = "No speed test yet"
            }
        } else {
            if let usage = currentUsage {
                let down = formatNetworkSpeed(speed: usage.downloadSpeed)
                let up   = formatNetworkSpeed(speed: usage.uploadSpeed)
                statusItem.button?.title = "↓\(down) ↑\(up)"
            } else {
                statusItem.button?.title = "Ready"
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
        // Simple upload test using httpbin.org
        guard let url = URL(string: "https://httpbin.org/post") else { return 0 }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create 1MB of test data
        let testData = Data(repeating: 0, count: 1024 * 1024)
        request.httpBody = testData
        
        let startTime = Date()
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            success = (error == nil && (response as? HTTPURLResponse)?.statusCode == 200)
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        let endTime = Date()
        let timeInterval = endTime.timeIntervalSince(startTime)
        
        if success && timeInterval > 0 {
            let bitsPerSecond = Double(testData.count * 8) / timeInterval
            return bitsPerSecond / 1_000_000 // Convert to Mbps
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
        
        speedTestTimer?.invalidate()
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: testInterval.rawValue, repeats: true) { [weak self] _ in
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
        speedTestTimer?.invalidate()
        networkUsageTimer?.invalidate()
        displayToggleTimer?.invalidate()
        networkChangeTimer?.invalidate()
    }
}

// Main
let app = NSApplication.shared
let delegate = SpeedTestMonitor()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
