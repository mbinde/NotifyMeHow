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

        // Check permissions (will show system prompt if needed)
        hasPromptedForPermission = true
        let hasPermissions = checkAccessibilityPermissions()

        // Auto-start if enabled and we have permissions
        if hasPermissions && settings.autoStartMonitoring {
            startMonitoring()
            rebuildMenu()  // Update menu to show "Running" status
        } else if !hasPermissions {
            // Poll for permission grant so we can auto-start once granted
            waitForAccessibilityPermission()
        }
    }

    private var permissionTimer: Timer?
    private var hasPromptedForPermission = false

    private func waitForAccessibilityPermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            // Check without prompting
            if hasAccessibilityPermissions() {
                timer.invalidate()
                self?.permissionTimer = nil
                // Now start monitoring if auto-start is enabled
                if self?.settings.autoStartMonitoring == true {
                    self?.startMonitoring()
                    self?.rebuildMenu()
                }
            }
        }
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()

        // Header with status
        let headerItem = NSMenuItem(title: "NotifyMeHow", action: nil, keyEquivalent: "")
        statusMenu.addItem(headerItem)

        // Status indicator
        let hasPerms = hasAccessibilityPermissions()
        let isRunning = monitor != nil
        let statusText: String
        if !hasPerms {
            statusText = "Needs Permission"
        } else if isRunning {
            statusText = "Running"
        } else {
            statusText = "Stopped"
        }
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

        statusMenu.addItem(NSMenuItem.separator())

        // Advanced Settings
        let prefsItem = NSMenuItem(title: "Advanced Settings...", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        statusMenu.addItem(prefsItem)

        // Only show accessibility settings link if permissions not granted
        if !hasAccessibilityPermissions() {
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
        // Only prompt if we haven't already, otherwise just check silently
        if hasPromptedForPermission {
            if !hasAccessibilityPermissions() {
                return
            }
        } else {
            hasPromptedForPermission = true
            if !checkAccessibilityPermissions() {
                return
            }
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
