import Cocoa
import ApplicationServices
import UserNotifications

/// Current app version - update this for each release
let appVersion = "0.1"

/// GitHub repository for update checks
let githubRepo = "mbinde/NotifyMeHow"

/// Menu bar application for NotifyMeHow
class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var monitor: NotificationMonitor?
    private let settings = Settings.shared
    private var latestVersion: String?
    private var updateURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with fixed length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Build menu first
        statusMenu = NSMenu()
        rebuildMenu()

        // Set up button with custom icon
        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.isTemplate = true  // Allows macOS to adapt color for light/dark mode
                button.image = icon
            } else {
                // Fallback to system symbol if custom icon not found
                button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "NotifyMeHow")
            }
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

        // Check for updates in the background
        checkForUpdates()
    }

    private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else {
                return
            }

            // Strip leading 'v' if present for comparison
            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            // Simple version comparison - check if remote is different and newer
            if remoteVersion != appVersion && self?.isNewerVersion(remoteVersion, than: appVersion) == true {
                DispatchQueue.main.async {
                    self?.latestVersion = remoteVersion
                    self?.updateURL = URL(string: htmlURL)
                    self?.rebuildMenu()
                }
            }
        }.resume()
    }

    /// Simple version comparison (handles versions like "0.1", "0.2", "1.0")
    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()

        // Header with status
        let headerItem = NSMenuItem(title: "NotifyMeHow v\(appVersion)", action: nil, keyEquivalent: "")
        statusMenu.addItem(headerItem)

        // Update available notification
        if let latestVersion = latestVersion {
            let updateItem = NSMenuItem(title: "Update Available (v\(latestVersion))", action: #selector(openUpdatePage(_:)), keyEquivalent: "")
            updateItem.target = self
            updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            statusMenu.addItem(updateItem)
        }

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

        // Start/Stop
        let toggleTitle = monitor == nil ? "Start Monitoring" : "Stop Monitoring"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.tag = 101
        statusMenu.addItem(toggleItem)

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
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.isTemplate = true
                button.image = icon
            }
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
        macOS notifications can't be resized or restyled—only repositioned.

        NotifyMeHow lets you:
        • Reposition system notifications to any corner or center
        • Create custom notifications with full control over size, colors, position, and animations
        • Set up rules to match notifications by app or keywords
        • Hide the system notification entirely and show only your custom version

        Use "Reposition To" to move system notifications.
        Use "Custom Notification Styles" to create rules and styles.

        NotifyMeHow v\(appVersion)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func openUpdatePage(_ sender: NSMenuItem) {
        if let url = updateURL {
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
