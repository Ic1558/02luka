import Cocoa

final class TestDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("======== MINIMAL TEST STARTING ========")
        NSLog("======== MINIMAL TEST STARTING ========")

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "TEST"
            print("======== STATUS ITEM CREATED ========")
            NSLog("======== STATUS ITEM CREATED ========")
        } else {
            print("======== ERROR: NO BUTTON ========")
            NSLog("======== ERROR: NO BUTTON ========")
        }
    }
}

@main
struct MinimalApp {
    static func main() {
        let app = NSApplication.shared
        app.delegate = TestDelegate()
        app.run()
    }
}
