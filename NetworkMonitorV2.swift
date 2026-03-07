import Cocoa
import Foundation

class NetworkMonitorApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastBytesReceived: Int64 = 0
    private var lastBytesSent: Int64 = 0
    private var lastUpdateTime: Date = Date()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startMonitoring()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "↓0.0B ↑0.0B"
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    
    private func startMonitoring() {
        // Initial reading
        updateNetworkStats()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateNetworkStats()
        }
    }
    
    private func updateNetworkStats() {
        let task = Process()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-I", "en0", "-b"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        parseNetworkStats(from: output)
    }
    
    private func parseNetworkStats(from output: String) {
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("en0") && line.contains("/") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if components.count >= 10 {
                    let bytesReceived = Int64(components[6]) ?? 0
                    let bytesSent = Int64(components[9]) ?? 0
                    
                    let currentTime = Date()
                    let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
                    
                    if timeInterval > 0 && lastBytesReceived > 0 {
                        let downloadSpeed = max(0, Double(bytesReceived - lastBytesReceived) / timeInterval)
                        let uploadSpeed = max(0, Double(bytesSent - lastBytesSent) / timeInterval)
                        
                        updateStatusBar(downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed)
                    }
                    
                    lastBytesReceived = bytesReceived
                    lastBytesSent = bytesSent
                    lastUpdateTime = currentTime
                    break
                }
            }
        }
    }
    
    private func updateStatusBar(downloadSpeed: Double, uploadSpeed: Double) {
        let downloadText = formatSpeed(speed: downloadSpeed)
        let uploadText = formatSpeed(speed: uploadSpeed)
        
        DispatchQueue.main.async {
            self.statusItem.button?.title = "↓\(downloadText) ↑\(uploadText)"
        }
    }
    
    private func formatSpeed(speed: Double) -> String {
        let bytesPerSecond = speed
        
        if bytesPerSecond >= 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSecond / (1024 * 1024))
        } else if bytesPerSecond >= 1024 {
            return String(format: "%.1fK", bytesPerSecond / 1024)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
}

// Main
let app = NSApplication.shared
let delegate = NetworkMonitorApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
