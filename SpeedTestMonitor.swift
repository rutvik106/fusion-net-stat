import Cocoa
import Foundation

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
    private var lastResult: SpeedTestResult?
    private var currentUsage: NetworkUsage?
    private var publicIP: PublicIP?
    private var testInterval: TimeInterval = 300 // 5 minutes default
    private var showingSpeedTest = false // Toggle state
    
    // Network usage tracking
    private var lastBytesReceived: Int64 = 0
    private var lastBytesSent: Int64 = 0
    private var lastNetworkUpdateTime: Date = Date()
    
    // Menu items
    private var interval5Item: NSMenuItem!
    private var interval10Item: NSMenuItem!
    private var interval30Item: NSMenuItem!
    private var interval60Item: NSMenuItem!
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
        
        interval5Item = NSMenuItem(title: "Every 5 minutes", action: #selector(setInterval5), keyEquivalent: "")
        interval5Item.target = self
        intervalMenu.addItem(interval5Item)
        
        interval10Item = NSMenuItem(title: "Every 10 minutes", action: #selector(setInterval10), keyEquivalent: "")
        interval10Item.target = self
        intervalMenu.addItem(interval10Item)
        
        interval30Item = NSMenuItem(title: "Every 30 minutes", action: #selector(setInterval30), keyEquivalent: "")
        interval30Item.target = self
        intervalMenu.addItem(interval30Item)
        
        interval60Item = NSMenuItem(title: "Every hour", action: #selector(setInterval60), keyEquivalent: "")
        interval60Item.target = self
        intervalMenu.addItem(interval60Item)
        
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
        networkUsageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateNetworkUsage()
        }
        
        // Get public IP on startup
        DispatchQueue.global(qos: .utility).async {
            self.updatePublicIP()
        }
        
        // Run initial speed test after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.runSpeedTest()
        }
        
        // Set up recurring speed tests
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: testInterval, repeats: true) { _ in
            self.runSpeedTest()
        }
        
        // Start display toggle (5 seconds each)
        displayToggleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.toggleDisplay()
        }
    }
    
    @objc private func runSpeedTest() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.performSpeedTest()
        }
    }
    
    private func updateNetworkUsage() {
        let task = Process()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-I", "en0", "-b"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        parseNetworkUsage(from: output)
    }
    
    private func parseNetworkUsage(from output: String) {
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("en0") && line.contains("/") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if components.count >= 10 {
                    let bytesReceived = Int64(components[6]) ?? 0
                    let bytesSent = Int64(components[9]) ?? 0
                    
                    let currentTime = Date()
                    let timeInterval = currentTime.timeIntervalSince(lastNetworkUpdateTime)
                    
                    if timeInterval > 0 && lastBytesReceived > 0 {
                        let downloadSpeed = max(0, Double(bytesReceived - lastBytesReceived) / timeInterval)
                        let uploadSpeed = max(0, Double(bytesSent - lastBytesSent) / timeInterval)
                        
                        let usage = NetworkUsage(
                            downloadSpeed: downloadSpeed,
                            uploadSpeed: uploadSpeed,
                            timestamp: currentTime
                        )
                        
                        currentUsage = usage
                        updateCurrentUsageItem(usage: usage)
                    }
                    
                    lastBytesReceived = bytesReceived
                    lastBytesSent = bytesSent
                    lastNetworkUpdateTime = currentTime
                    break
                }
            }
        }
    }
    
    private func updateCurrentUsageItem(usage: NetworkUsage) {
        let downloadText = formatNetworkSpeed(speed: usage.downloadSpeed)
        let uploadText = formatNetworkSpeed(speed: usage.uploadSpeed)
        
        DispatchQueue.main.async {
            self.currentUsageItem.title = "Current: ↓\(downloadText) ↑\(uploadText)"
            
            // Only update menu bar if currently showing usage
            if !self.showingSpeedTest {
                self.statusItem.button?.title = "↓\(downloadText) ↑\(uploadText)"
            }
        }
    }
    
    private func formatNetworkSpeed(speed: Double) -> String {
        let bytesPerSecond = speed
        
        if bytesPerSecond >= 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSecond / (1024 * 1024))
        } else if bytesPerSecond >= 1024 {
            return String(format: "%.1fK", bytesPerSecond / 1024)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }
    
    @objc private func refreshPublicIP() {
        DispatchQueue.global(qos: .utility).async {
            self.updatePublicIP()
        }
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
    
    private func getPublicIPv4() -> String {
        guard let url = URL(string: "https://api.ipify.org") else { return "Unknown" }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = "Unknown"
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                result = ip
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        return result
    }
    
    private func getPublicIPv6() -> String {
        guard let url = URL(string: "https://api64.ipify.org") else { return "Unknown" }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = "Unknown"
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                result = ip
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        return result
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
            // Show speed test results
            if let result = lastResult {
                showSpeedTestResult(result: result)
            } else {
                statusItem.button?.title = "No speed test yet"
            }
        } else {
            // Show current usage
            if let usage = currentUsage {
                updateCurrentUsageItem(usage: usage)
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
        // Use fast.com's speed test API
        guard let url = URL(string: "https://fast.com/api/fastscore") else { return 0 }
        
        let startTime = Date()
        var totalBytes: Int64 = 0
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String {
                totalBytes = Int64(contentLength) ?? 0
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
    @objc private func setInterval5() {
        setInterval(300)
    }
    
    @objc private func setInterval10() {
        setInterval(600)
    }
    
    @objc private func setInterval30() {
        setInterval(1800)
    }
    
    @objc private func setInterval60() {
        setInterval(3600)
    }
    
    private func setInterval(_ interval: TimeInterval) {
        testInterval = interval
        
        speedTestTimer?.invalidate()
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: testInterval, repeats: true) { _ in
            self.runSpeedTest()
        }
        
        updateIntervalMenu()
    }
    
    private func updateIntervalMenu() {
        interval5Item.state = testInterval == 300 ? .on : .off
        interval10Item.state = testInterval == 600 ? .on : .off
        interval30Item.state = testInterval == 1800 ? .on : .off
        interval60Item.state = testInterval == 3600 ? .on : .off
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        speedTestTimer?.invalidate()
        networkUsageTimer?.invalidate()
        displayToggleTimer?.invalidate()
    }
}

// Main
let app = NSApplication.shared
let delegate = SpeedTestMonitor()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
