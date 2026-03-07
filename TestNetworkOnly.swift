import Cocoa
import Foundation

class TestNetworkApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        testNetworkDetection()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Testing..."
    }
    
    private func testNetworkDetection() {
        print("Testing network detection...")
        
        // Test each method
        testMethod1()
        testMethod2()
        testMethod3()
        
        DispatchQueue.main.async {
            self.statusItem.button?.title = "Done"
        }
    }
    
    private func testMethod1() {
        print("Testing method 1: networksetup")
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getairportnetwork", "en0"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("Method 1 result: \(output)")
    }
    
    private func testMethod2() {
        print("Testing method 2: system_profiler")
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPAirPortDataType"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("Method 2 result: \(output.prefix(200))...")
    }
    
    private func testMethod3() {
        print("Testing method 3: airport utility")
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        
        let task = Process()
        task.launchPath = airportPath
        task.arguments = ["-I"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("Method 3 result: \(output)")
    }
}

// Main
let app = NSApplication.shared
let delegate = TestNetworkApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
