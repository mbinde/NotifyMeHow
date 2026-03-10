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

        // Prompt for permissions if needed (shows system dialog)
        _ = checkAccessibilityPermissions()

        // Enable launch at login by default on first run
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            settings.launchAtLogin = true
        }

        // Always try to start monitoring if auto-start is enabled
        // It will just silently fail if permissions aren't granted yet
        if settings.autoStartMonitoring {
            startMonitoring()
            rebuildMenu()
        }
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()

        // Header with status
        let headerItem = NSMenuItem(title: "NotifyMeHow", action: nil, keyEquivalent: "")
        statusMenu.addItem(headerItem)

        // How it works
        let helpItem = NSMenuItem(title: "How It Works...", action: #selector(showHowItWorks(_:)), keyEquivalent: "")
        helpItem.target = self
        statusMenu.addItem(helpItem)

        // Status indicator - use monitor state as primary indicator since
        // hasAccessibilityPermissions() can return false even when we have permission
        // (e.g., when launched from a terminal that doesn't have permission)
        let isRunning = monitor != nil
        let hasPerms = isRunning || hasAccessibilityPermissions()
        let statusText: String
        if isRunning {
            statusText = "Running"
        } else if hasPerms {
            statusText = "Stopped"
        } else {
            statusText = "Needs Permission"
        }
        let statusMenuItem = NSMenuItem(title: "Status: \(statusText)", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        statusMenu.addItem(statusMenuItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Position submenu with checkmarks
        let positionItem = NSMenuItem(title: "Reposition To", action: nil, keyEquivalent: "")
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

        statusMenu.addItem(NSMenuItem.separator())

        // Custom notification styles
        let prefsItem = NSMenuItem(title: "Custom Notification Styles...", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        prefsItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
        statusMenu.addItem(prefsItem)

        // Only show accessibility settings link if we don't have permissions
        // (monitor running means we have permissions regardless of what the API returns)
        if !hasPerms {
            let accessItem = NSMenuItem(title: "Grant Accessibility Permission...", action: #selector(openAccessibilitySettings(_:)), keyEquivalent: "")
            accessItem.target = self
            statusMenu.addItem(accessItem)
        }

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
        // Just try to start - it will fail gracefully if no permissions
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

    @objc func showPreferences(_ sender: NSMenuItem) {
        PreferencesWindowController.shared.showWindow()
    }

    @objc func openAccessibilitySettings(_ sender: NSMenuItem) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showHowItWorks(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "How NotifyMeHow Works"
        alert.informativeText = """
        macOS Limitations:
        • System notifications cannot be resized or restyled
        • They can only be repositioned on screen

        What NotifyMeHow Can Do:
        • Reposition system notifications to any corner
        • Create custom duplicate notifications with full styling (size, colors, fonts, icons)
        • Apply different styles based on which app sent the notification

        The "Reposition To" menu moves system notifications.
        Use "Custom Notification Styles" to create styled duplicates that appear alongside (or instead of) the system notification.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp(_ sender: NSMenuItem) {
        monitor?.stop()
        NSApplication.shared.terminate(nil)
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

    // Set up main menu with Edit menu for standard keyboard shortcuts (Cmd+A, Cmd+C, etc.)
    setupMainMenu()

    app.run()
}

/// Set up a minimal main menu with Edit menu for text field keyboard shortcuts
private func setupMainMenu() {
    let mainMenu = NSMenu()

    // App menu (required)
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(title: "Quit NotifyMeHow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Edit menu (enables Cmd+A, Cmd+C, Cmd+V, Cmd+X in text fields)
    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")

    editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
    editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    NSApplication.shared.mainMenu = mainMenu
}
