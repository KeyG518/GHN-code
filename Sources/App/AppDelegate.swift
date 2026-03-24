import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        // Prevent ⌘W from closing the window — we handle it as "close pane"
        NSWindow.swizzlePerformClose()

        // Style the main window for a clean integrated look
        DispatchQueue.main.async {
            if let window = NSApp.mainWindow ?? NSApp.windows.first {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.043, alpha: 1)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save state is handled by the SwiftUI lifecycle
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}

// MARK: - Swizzle NSWindow.performClose to prevent ⌘W from closing the window

extension NSWindow {
    static func swizzlePerformClose() {
        let original = #selector(NSWindow.performClose(_:))
        let swizzled = #selector(NSWindow.ghn_performClose(_:))
        guard let originalMethod = class_getInstanceMethod(NSWindow.self, original),
              let swizzledMethod = class_getInstanceMethod(NSWindow.self, swizzled) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func ghn_performClose(_ sender: Any?) {
        // Only block close for the main app window — ⌘W is handled by AppCommands as "Close Pane"
        if self === NSApp.mainWindow {
            return
        }
        // For other windows (shortcuts panel, etc.), call the original implementation
        ghn_performClose(sender)
    }
}
