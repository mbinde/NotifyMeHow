import Cocoa
import ApplicationServices
import UserNotifications

/// Current app version - update this for each release
let appVersion = "0.2"

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
    private var aboutWindow: NSWindow?

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

    deinit {
        NotificationCenter.default.removeObserver(self)
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

        // Start/Stop at the top
        let isRunning = monitor != nil
        let hasPerms = isRunning || hasAccessibilityPermissions()
        let toggleTitle = isRunning ? "Stop Monitoring" : "Start Monitoring"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring(_:)), keyEquivalent: "")
        toggleItem.target = self
        if isRunning {
            toggleItem.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil)
        } else {
            toggleItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
        }
        statusMenu.addItem(toggleItem)

        // Version info
        let versionItem = NSMenuItem(title: "NotifyMeHow v\(appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        statusMenu.addItem(versionItem)

        // How it works
        let helpItem = NSMenuItem(title: "How It Works...", action: #selector(showHowItWorks(_:)), keyEquivalent: "")
        helpItem.target = self
        statusMenu.addItem(helpItem)

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

        // Settings
        let prefsItem = NSMenuItem(title: "Settings...", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        statusMenu.addItem(prefsItem)

        // Only show accessibility settings link if we don't have permissions
        if !hasPerms {
            let accessItem = NSMenuItem(title: "Grant Accessibility Permission...", action: #selector(openAccessibilitySettings(_:)), keyEquivalent: "")
            accessItem.target = self
            statusMenu.addItem(accessItem)
        }

        statusMenu.addItem(NSMenuItem.separator())

        // Check for Updates
        if let latestVersion = latestVersion {
            let updateItem = NSMenuItem(title: "Update Available (v\(latestVersion))...", action: #selector(openUpdatePage(_:)), keyEquivalent: "")
            updateItem.target = self
            updateItem.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            statusMenu.addItem(updateItem)
        } else {
            let checkUpdateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdatesManual(_:)), keyEquivalent: "")
            checkUpdateItem.target = self
            statusMenu.addItem(checkUpdateItem)
        }

        // Quit
        let quitItem = NSMenuItem(title: "Quit NotifyMeHow", action: #selector(quitApp(_:)), keyEquivalent: "q")
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About NotifyMeHow"
        window.center()

        let contentView = window.contentView!
        let padding: CGFloat = 20
        var y = contentView.frame.height - padding

        // Title
        y -= 24
        let titleLabel = NSTextField(labelWithString: "NotifyMeHow v\(appVersion)")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: padding, y: y, width: 380, height: 24)
        contentView.addSubview(titleLabel)

        // Description
        y -= 140
        let descText = """
        macOS notifications can't be resized or restyled—only repositioned.

        NotifyMeHow lets you:
        • Reposition system notifications to any corner
        • Create custom notification styles with control over size, colors, position, and animations
        • Set up rules to match notifications by app or keywords
        • Optionally hide the system notification and show only your custom version

        Use "Reposition To" to move system notifications.
        Use "Settings" to create rules and custom styles.
        """
        let descLabel = NSTextField(wrappingLabelWithString: descText)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.frame = NSRect(x: padding, y: y, width: 380, height: 140)
        contentView.addSubview(descLabel)

        // Links section
        y -= 30
        let linksLabel = NSTextField(labelWithString: "Links:")
        linksLabel.font = NSFont.boldSystemFont(ofSize: 12)
        linksLabel.frame = NSRect(x: padding, y: y, width: 380, height: 18)
        contentView.addSubview(linksLabel)

        y -= 22
        let githubButton = NSButton(title: "GitHub: github.com/\(githubRepo)", target: self, action: #selector(openGitHub(_:)))
        githubButton.bezelStyle = .inline
        githubButton.frame = NSRect(x: padding - 8, y: y, width: 280, height: 20)
        contentView.addSubview(githubButton)

        y -= 22
        let emailButton = NSButton(title: "Contact: binde@motleywoods.dev", target: self, action: #selector(openEmail(_:)))
        emailButton.bezelStyle = .inline
        emailButton.frame = NSRect(x: padding - 8, y: y, width: 280, height: 20)
        contentView.addSubview(emailButton)

        // Close button
        let closeButton = NSButton(title: "Close", target: window, action: #selector(NSWindow.close))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.frame = NSRect(x: contentView.frame.width - padding - 80, y: 15, width: 80, height: 28)
        contentView.addSubview(closeButton)

        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Keep a reference so window doesn't disappear
        self.aboutWindow = window
    }

    @objc func openGitHub(_ sender: Any) {
        if let url = URL(string: "https://github.com/\(githubRepo)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openEmail(_ sender: Any) {
        if let url = URL(string: "mailto:binde@motleywoods.dev") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openUpdatePage(_ sender: NSMenuItem) {
        if let url = updateURL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func checkForUpdatesManual(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    let alert = NSAlert()
                    alert.messageText = "Update Check Failed"
                    alert.informativeText = "Could not connect to GitHub: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    let alert = NSAlert()
                    alert.messageText = "Update Check Failed"
                    alert.informativeText = "Could not parse response from GitHub."
                    alert.alertStyle = .warning
                    alert.runModal()
                    return
                }

                // Strip leading 'v' if present for comparison
                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                if remoteVersion != appVersion && self.isNewerVersion(remoteVersion, than: appVersion) {
                    self.latestVersion = remoteVersion
                    self.updateURL = URL(string: htmlURL)
                    self.rebuildMenu()

                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(remoteVersion) is available. You are running version \(appVersion)."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = self.updateURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date"
                    alert.informativeText = "NotifyMeHow \(appVersion) is the latest version."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            }
        }.resume()
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
