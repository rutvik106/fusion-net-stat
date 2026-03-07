import Cocoa
import Foundation

class TestNetworkApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var counter = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startTest()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🔄 Testing"
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    
    private func startTest() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.testNetwork()
        }
    }
    
    private func testNetwork() {
        counter += 1
        print("=== Test \(counter) ===")
        
        let task = Process()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-I", "en0", "-b"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        print("Netstat output length: \(output.count)")
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("en0") && line.contains("/") {
                print("Found: \(line.prefix(50))...")
                DispatchQueue.main.async {
                    self.statusItem.button?.title = "🔄 \(self.counter)"
                }
                return
            }
        }
        
        print("No en0 line found!")
        DispatchQueue.main.async {
            self.statusItem.button?.title = "❌ \(self.counter)"
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
}

// Main
let app = NSApplication.shared
let delegate = TestNetworkApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
