import Cocoa
import Foundation

class NetworkMonitor: NSObject {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastBytesReceived: Int64 = 0
    private var lastBytesSent: Int64 = 0
    private var lastUpdateTime: Date = Date()
    
    override init() {
        super.init()
        setupStatusBar()
        startMonitoring()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⏱ 0↓ 0↑"
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateNetworkStats()
        }
    }
    
    private func updateNetworkStats() {
        // Try to find the active network interface
        let interfaces = ["en0", "en1", "en2", "en3", "en4", "en5", "en6"]
        var foundStats = false
        
        for interface in interfaces {
            let task = Process()
            task.launchPath = "/usr/bin/netstat"
            task.arguments = ["-b", "-I", interface]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Debug: print what we're trying
            print("Checking interface: \(interface)")
            print("Output: \(output.prefix(200))")
            
            if parseNetworkStats(from: output, interface: interface) {
                foundStats = true
                print("Found stats on interface: \(interface)")
                break
            }
        }
        
        if !foundStats {
            print("No network interface found with stats")
            DispatchQueue.main.async {
                self.statusItem.button?.title = "↓0.0B ↑0.0B"
            }
        }
    }
    
    private func parseNetworkStats(from output: String, interface: String) -> Bool {
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix(interface) && !line.contains("Name") {
                print("Found line for \(interface): \(line)")
                
                // Handle wrapped lines - look for the line with IP address format
                if line.contains(".") && line.contains("/") {
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    print("Components count: \(components.count)")
                    print("Components: \(components)")
                    
                    if components.count >= 10 {
                        let bytesReceived = Int64(components[6]) ?? 0
                        let bytesSent = Int64(components[9]) ?? 0
                        
                        print("Bytes received: \(bytesReceived), Bytes sent: \(bytesSent)")
                        
                        let currentTime = Date()
                        let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
                        
                        if timeInterval > 0 {
                            let downloadSpeed = Double(bytesReceived - lastBytesReceived) / timeInterval
                            let uploadSpeed = Double(bytesSent - lastBytesSent) / timeInterval
                            
                            print("Download speed: \(downloadSpeed), Upload speed: \(uploadSpeed)")
                            
                            updateStatusBar(downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed)
                            
                            lastBytesReceived = bytesReceived
                            lastBytesSent = bytesSent
                            lastUpdateTime = currentTime
                        }
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func updateStatusBar(downloadSpeed: Double, uploadSpeed: Double) {
        let downloadText = formatSpeed(speed: downloadSpeed)
        let uploadText = formatSpeed(speed: uploadSpeed)
        
        DispatchQueue.main.async {
            self.statusItem.button?.title = "↓\(downloadText) ↑\(uploadText)"
        }
    }
    
    private func formatSpeed(speed: Double) -> String {
        let bytesPerSecond = max(0, speed)
        
        if bytesPerSecond >= 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSecond / (1024 * 1024))
        } else if bytesPerSecond >= 1024 {
            return String(format: "%.1fK", bytesPerSecond / 1024)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var networkMonitor: NetworkMonitor!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        networkMonitor = NetworkMonitor()
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}

// Main function to run the app
func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    
    // Set activation policy before running
    app.setActivationPolicy(.accessory)
    
    // Run the app
    app.run()
}

// Run the application
main()
