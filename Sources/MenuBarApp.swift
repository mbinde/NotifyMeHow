import Cocoa
import ApplicationServices
import UserNotifications

/// Menu bar application for NotifyMeHow
class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: NotificationMonitor?
    private var currentPosition: NotificationPosition = .bottomRight

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "NotifyMeHow")
            button.toolTip = "NotifyMeHow - Click to configure notification position"
        }

        // Create menu
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "NotifyMeHow", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Position submenu
        let positionItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()

        let positions: [(String, NotificationPosition.Corner, String)] = [
            ("Top Right (Default)", .topRight, "tr"),
            ("Top Left", .topLeft, "tl"),
            ("Bottom Right", .bottomRight, "br"),
            ("Bottom Left", .bottomLeft, "bl"),
            ("Center", .center, "c")
        ]

        for (title, corner, _) in positions {
            let item = NSMenuItem(title: title, action: #selector(setPositionAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = corner
            positionMenu.addItem(item)
        }

        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(NSMenuItem.separator())

        // Status
        let statusItem = NSMenuItem(title: "Status: Stopped", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Start/Stop
        let toggleItem = NSMenuItem(title: "Start Monitoring", action: #selector(toggleMonitoring(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.tag = 101
        menu.addItem(toggleItem)

        // Test notification
        let testItem = NSMenuItem(title: "Send Test Notification", action: #selector(sendTestNotification(_:)), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        // Accessibility
        let accessItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings(_:)), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Check permissions
        if !checkAccessibilityPermissions() {
            showAccessibilityAlert()
        }
    }

    @objc func setPositionAction(_ sender: NSMenuItem) {
        guard let corner = sender.representedObject as? NotificationPosition.Corner else { return }

        switch corner {
        case .topRight:
            currentPosition = NotificationPosition(corner: .topRight, offsetX: 20, offsetY: 40)
        case .topLeft:
            currentPosition = NotificationPosition(corner: .topLeft, offsetX: 20, offsetY: 40)
        case .bottomRight:
            currentPosition = NotificationPosition(corner: .bottomRight, offsetX: 20, offsetY: 20)
        case .bottomLeft:
            currentPosition = NotificationPosition(corner: .bottomLeft, offsetX: 20, offsetY: 20)
        case .center:
            currentPosition = NotificationPosition(corner: .center, offsetX: 0, offsetY: 0)
        }

        monitor?.setPosition(currentPosition)

        // Update menu checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item == sender) ? .on : .off
            }
        }
    }

    @objc func toggleMonitoring(_ sender: NSMenuItem) {
        if monitor == nil {
            // Start monitoring
            if !checkAccessibilityPermissions() {
                showAccessibilityAlert()
                return
            }

            monitor = NotificationMonitor(position: currentPosition, scaleFactor: 1.0)
            monitor?.start()

            sender.title = "Stop Monitoring"
            updateStatus("Running")

            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "NotifyMeHow Active")
            }
        } else {
            // Stop monitoring
            monitor?.stop()
            monitor = nil

            sender.title = "Start Monitoring"
            updateStatus("Stopped")

            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "NotifyMeHow")
            }
        }
    }

    @objc func sendTestNotification(_ sender: NSMenuItem) {
        // Use UserNotifications framework (modern API)
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Test Notification"
                content.body = "This is a test notification from NotifyMeHow"
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil  // Deliver immediately
                )

                center.add(request) { error in
                    if let error = error {
                        print("Failed to send notification: \(error)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    // Fall back to osascript if notification permissions not granted
                    let script = "display notification \"Test from NotifyMeHow\" with title \"Test Notification\""
                    let task = Process()
                    task.launchPath = "/usr/bin/osascript"
                    task.arguments = ["-e", script]
                    try? task.run()
                }
            }
        }
    }

    @objc func openAccessibilitySettings(_ sender: NSMenuItem) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp(_ sender: NSMenuItem) {
        monitor?.stop()
        NSApplication.shared.terminate(nil)
    }

    private func updateStatus(_ status: String) {
        if let menu = statusItem.menu,
           let item = menu.item(withTag: 100) {
            item.title = "Status: \(status)"
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "NotifyMeHow needs accessibility permissions to move notification windows.\n\nClick 'Open Settings' to grant permission."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings(NSMenuItem())
        }
    }
}

/// Run as a menu bar app
func runMenuBarApp() {
    let app = NSApplication.shared
    let delegate = MenuBarApp()
    app.delegate = delegate

    // Hide from dock (menu bar only)
    app.setActivationPolicy(.accessory)

    app.run()
}
