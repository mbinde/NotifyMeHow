import Cocoa
import ApplicationServices
import UserNotifications

/// Menu bar application for NotifyMeHow
class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var monitor: NotificationMonitor?
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with fixed length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Build menu first
        statusMenu = NSMenu()
        rebuildMenu()

        // Set up button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "NotifyMeHow")
            button.toolTip = "NotifyMeHow - Click to configure notification position"
        }

        // Assign menu to status item
        statusItem.menu = statusMenu

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: Settings.didChangeNotification,
            object: nil
        )

        // Check permissions and auto-start
        if !checkAccessibilityPermissions() {
            showAccessibilityAlert()
        } else if settings.autoStartMonitoring {
            startMonitoring()
            rebuildMenu()  // Update menu to show "Running" status
        }
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()

        // Header with status
        let headerItem = NSMenuItem(title: "NotifyMeHow", action: nil, keyEquivalent: "")
        statusMenu.addItem(headerItem)

        // Status indicator
        let isRunning = monitor != nil
        let statusText = isRunning ? "Running" : "Stopped"
        let statusMenuItem = NSMenuItem(title: "Status: \(statusText)", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        statusMenu.addItem(statusMenuItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Position submenu with checkmarks
        let positionItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()

        let positions: [(String, NotificationPosition.Corner)] = [
            ("Top Left", .topLeft),
            ("Top Center", .topCenter),
            ("Top Right (Default)", .topRight),
            ("Middle Left", .middleLeft),
            ("Center", .center),
            ("Middle Right", .middleRight),
            ("Bottom Left", .bottomLeft),
            ("Bottom Center", .bottomCenter),
            ("Bottom Right", .bottomRight)
        ]

        for (title, corner) in positions {
            let item = NSMenuItem(title: title, action: #selector(setPositionAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = corner
            item.state = (corner == settings.positionCorner) ? .on : .off
            positionMenu.addItem(item)
        }

        positionItem.submenu = positionMenu
        statusMenu.addItem(positionItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Start/Stop
        let toggleTitle = monitor == nil ? "Start Monitoring" : "Stop Monitoring"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.tag = 101
        statusMenu.addItem(toggleItem)

        // Test notification
        let testItem = NSMenuItem(title: "Send Test Notification", action: #selector(sendTestNotification(_:)), keyEquivalent: "t")
        testItem.target = self
        statusMenu.addItem(testItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Advanced Settings
        let prefsItem = NSMenuItem(title: "Advanced Settings...", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        statusMenu.addItem(prefsItem)

        // Accessibility settings
        let accessItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings(_:)), keyEquivalent: "")
        accessItem.target = self
        statusMenu.addItem(accessItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    @objc func settingsDidChange() {
        rebuildMenu()

        // Update monitor with new settings if running
        if let monitor = monitor {
            monitor.setPosition(settings.position)

            if settings.enableCustomNotification {
                monitor.enableCustomNotifications(config: settings.buildCustomConfig())
            } else {
                monitor.disableCustomNotifications()
            }
        }
    }

    @objc func setPositionAction(_ sender: NSMenuItem) {
        guard let corner = sender.representedObject as? NotificationPosition.Corner else { return }
        settings.positionCorner = corner

        // Update offsets to defaults for this corner
        switch corner {
        case .topRight, .topLeft, .topCenter:
            settings.positionOffsetX = (corner == .topCenter) ? 0 : 20
            settings.positionOffsetY = 40
        case .bottomRight, .bottomLeft, .bottomCenter:
            settings.positionOffsetX = (corner == .bottomCenter) ? 0 : 20
            settings.positionOffsetY = 20
        case .middleLeft, .middleRight:
            settings.positionOffsetX = 20
            settings.positionOffsetY = 0
        case .center:
            settings.positionOffsetX = 0
            settings.positionOffsetY = 0
        }
    }

    @objc func toggleCustomNotification(_ sender: NSMenuItem) {
        settings.enableCustomNotification = !settings.enableCustomNotification
    }

    @objc func toggleMonitoring(_ sender: NSMenuItem) {
        if monitor == nil {
            startMonitoring()
        } else {
            stopMonitoring()
        }
        rebuildMenu()
    }

    private func startMonitoring() {
        if !checkAccessibilityPermissions() {
            showAccessibilityAlert()
            return
        }

        monitor = NotificationMonitor(position: settings.position, scaleFactor: settings.scaleFactor)

        if settings.enableCustomNotification {
            monitor?.enableCustomNotifications(config: settings.buildCustomConfig())
        }

        monitor?.start()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "NotifyMeHow Active")
        }
    }

    private func stopMonitoring() {
        monitor?.stop()
        monitor = nil

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "NotifyMeHow")
        }
    }

    @objc func sendTestNotification(_ sender: NSMenuItem) {
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
                    trigger: nil
                )

                center.add(request) { error in
                    if let error = error {
                        print("Failed to send notification: \(error)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let script = "display notification \"Test from NotifyMeHow\" with title \"Test Notification\""
                    let task = Process()
                    task.launchPath = "/usr/bin/osascript"
                    task.arguments = ["-e", script]
                    try? task.run()
                }
            }
        }
    }

    @objc func showPreferences(_ sender: NSMenuItem) {
        PreferencesWindowController.shared.showWindow()
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

/// Singleton to hold the delegate reference
private var menuBarAppDelegate: MenuBarApp?

/// Run as a menu bar app
func runMenuBarApp() {
    let app = NSApplication.shared
    menuBarAppDelegate = MenuBarApp()
    app.delegate = menuBarAppDelegate

    // Hide from dock (menu bar only)
    app.setActivationPolicy(.accessory)

    app.run()
}
