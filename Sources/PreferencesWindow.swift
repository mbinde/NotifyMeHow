import Cocoa

/// Preferences window controller
class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private var generalTab: GeneralPreferencesView?
    private var rulesTab: RulesPreferencesView?
    private var stylesTab: StylesPreferencesView?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotifyMeHow - Advanced Settings"
        window.center()

        super.init(window: window)

        // Create tab view with inset to avoid clipping
        let inset: CGFloat = 10
        let tabView = NSTabView(frame: NSRect(x: inset, y: inset, width: 480 - inset * 2, height: 360 - inset * 2))
        tabView.autoresizingMask = [.width, .height]

        // General tab
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalTab = GeneralPreferencesView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))
        generalItem.view = generalTab
        tabView.addTabViewItem(generalItem)

        // Rules tab
        let rulesItem = NSTabViewItem(identifier: "rules")
        rulesItem.label = "Rules"
        rulesTab = RulesPreferencesView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))
        rulesItem.view = rulesTab
        tabView.addTabViewItem(rulesItem)

        // Styles tab
        let stylesItem = NSTabViewItem(identifier: "styles")
        stylesItem.label = "Styles"
        stylesTab = StylesPreferencesView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))
        stylesItem.view = stylesTab
        tabView.addTabViewItem(stylesItem)

        window.contentView?.addSubview(tabView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        generalTab?.loadSettings()
        rulesTab?.loadRules()
        stylesTab?.loadStyles()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Prevent auto-focus on first text field (avoids jarring selection animation)
        // Delay slightly so it happens after the window finishes setting up
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self.window?.contentView)
        }
    }
}

// MARK: - General Preferences Tab

class GeneralPreferencesView: NSView, NSTextFieldDelegate {
    private let settings = Settings.shared

    private var positionPopup: NSPopUpButton!
    private var offsetXField: NSTextField!
    private var offsetYField: NSTextField!
    private var autoStartCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let padding: CGFloat = 20
        var y = frame.height - padding

        // Position
        y -= 25
        let positionHeader = createLabel("Notification Position", bold: true)
        positionHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        addSubview(positionHeader)

        y -= 30
        let positionLabel = createLabel("Position:")
        positionLabel.frame = NSRect(x: padding, y: y + 3, width: 80, height: 22)
        addSubview(positionLabel)

        positionPopup = NSPopUpButton(frame: NSRect(x: padding + 90, y: y, width: 150, height: 26), pullsDown: false)
        positionPopup.addItems(withTitles: [
            "Top Left", "Top Center", "Top Right",
            "Middle Left", "Center", "Middle Right",
            "Bottom Left", "Bottom Center", "Bottom Right"
        ])
        positionPopup.target = self
        positionPopup.action = #selector(positionChanged)
        addSubview(positionPopup)

        y -= 30
        let offsetLabel = createLabel("Fine-tune:")
        offsetLabel.frame = NSRect(x: padding, y: y + 2, width: 80, height: 22)
        addSubview(offsetLabel)

        let offsetXLabel = createLabel("X:")
        offsetXLabel.frame = NSRect(x: padding + 70, y: y + 2, width: 20, height: 22)
        addSubview(offsetXLabel)

        offsetXField = NSTextField(frame: NSRect(x: padding + 90, y: y, width: 50, height: 22))
        offsetXField.placeholderString = "20"
        offsetXField.delegate = self
        offsetXField.target = self
        offsetXField.action = #selector(offsetChanged)
        addSubview(offsetXField)

        let offsetYLabel = createLabel("Y:")
        offsetYLabel.frame = NSRect(x: padding + 150, y: y + 2, width: 20, height: 22)
        addSubview(offsetYLabel)

        offsetYField = NSTextField(frame: NSRect(x: padding + 170, y: y, width: 50, height: 22))
        offsetYField.placeholderString = "40"
        offsetYField.delegate = self
        offsetYField.target = self
        offsetYField.action = #selector(offsetChanged)
        addSubview(offsetYField)

        let pxLabel = createLabel("px")
        pxLabel.frame = NSRect(x: padding + 225, y: y + 2, width: 20, height: 22)
        addSubview(pxLabel)

        // App Settings
        y -= 40
        let appHeader = createLabel("App Settings", bold: true)
        appHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        addSubview(appHeader)

        y -= 26
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.frame = NSRect(x: padding, y: y, width: 350, height: 22)
        addSubview(launchAtLoginCheckbox)

        y -= 24
        autoStartCheckbox = NSButton(checkboxWithTitle: "Start monitoring automatically when app launches", target: self, action: #selector(autoStartChanged))
        autoStartCheckbox.frame = NSRect(x: padding, y: y, width: 350, height: 22)
        addSubview(autoStartCheckbox)

        // Export/Import
        y -= 40
        let configHeader = createLabel("Backup & Transfer", bold: true)
        configHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        addSubview(configHeader)

        y -= 18
        let configHint = createLabel("Export all settings, styles, and rules to copy to another computer.")
        configHint.font = NSFont.systemFont(ofSize: 11)
        configHint.textColor = .secondaryLabelColor
        configHint.frame = NSRect(x: padding, y: y, width: 400, height: 16)
        addSubview(configHint)

        y -= 30
        let exportButton = NSButton(frame: NSRect(x: padding, y: y, width: 100, height: 28))
        exportButton.title = "Export..."
        exportButton.bezelStyle = .rounded
        exportButton.target = self
        exportButton.action = #selector(exportSettings)
        addSubview(exportButton)

        let importButton = NSButton(frame: NSRect(x: padding + 110, y: y, width: 100, height: 28))
        importButton.title = "Import..."
        importButton.bezelStyle = .rounded
        importButton.target = self
        importButton.action = #selector(importSettings)
        addSubview(importButton)
    }

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    func loadSettings() {
        positionPopup.selectItem(at: cornerToIndex(settings.positionCorner))
        offsetXField.stringValue = String(Int(settings.positionOffsetX))
        offsetYField.stringValue = String(Int(settings.positionOffsetY))
        launchAtLoginCheckbox.state = settings.launchAtLogin ? .on : .off
        autoStartCheckbox.state = settings.autoStartMonitoring ? .on : .off
        validateOffsets()
    }

    private func cornerToIndex(_ corner: NotificationPosition.Corner) -> Int {
        switch corner {
        case .topLeft: return 0
        case .topCenter: return 1
        case .topRight: return 2
        case .middleLeft: return 3
        case .center: return 4
        case .middleRight: return 5
        case .bottomLeft: return 6
        case .bottomCenter: return 7
        case .bottomRight: return 8
        }
    }

    private func indexToCorner(_ index: Int) -> NotificationPosition.Corner {
        switch index {
        case 0: return .topLeft
        case 1: return .topCenter
        case 2: return .topRight
        case 3: return .middleLeft
        case 4: return .center
        case 5: return .middleRight
        case 6: return .bottomLeft
        case 7: return .bottomCenter
        case 8: return .bottomRight
        default: return .topRight
        }
    }

    @objc private func positionChanged() {
        settings.positionCorner = indexToCorner(positionPopup.indexOfSelectedItem)
        validateOffsets()
    }

    @objc private func offsetChanged() {
        if let x = Double(offsetXField.stringValue) {
            settings.positionOffsetX = CGFloat(x)
        }
        if let y = Double(offsetYField.stringValue) {
            settings.positionOffsetY = CGFloat(y)
        }
        validateOffsets()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        // Save offset changes as user types
        if let x = Double(offsetXField.stringValue) {
            settings.positionOffsetX = CGFloat(x)
        }
        if let y = Double(offsetYField.stringValue) {
            settings.positionOffsetY = CGFloat(y)
        }
        validateOffsets()
    }

    /// Check if current offsets would push notification off-screen and highlight fields in red if so
    private func validateOffsets() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let offsetX = CGFloat(Double(offsetXField.stringValue) ?? 0)
        let offsetY = CGFloat(Double(offsetYField.stringValue) ?? 0)

        // Estimate notification size (standard macOS notification is roughly 360x90)
        let estimatedWidth: CGFloat = 360
        let estimatedHeight: CGFloat = 90

        let corner = indexToCorner(positionPopup.indexOfSelectedItem)

        // Calculate where the notification would be positioned
        var wouldBeOffScreenX = false
        var wouldBeOffScreenY = false

        switch corner {
        case .topRight, .middleRight, .bottomRight:
            wouldBeOffScreenX = offsetX > screenFrame.width - estimatedWidth
        case .topLeft, .middleLeft, .bottomLeft:
            wouldBeOffScreenX = offsetX > screenFrame.width - estimatedWidth
        case .topCenter, .center, .bottomCenter:
            break  // Center positions ignore X offset
        }

        switch corner {
        case .topLeft, .topCenter, .topRight:
            wouldBeOffScreenY = offsetY > screenFrame.height - estimatedHeight
        case .bottomLeft, .bottomCenter, .bottomRight:
            wouldBeOffScreenY = offsetY > screenFrame.height - estimatedHeight
        case .middleLeft, .center, .middleRight:
            break  // Middle positions ignore Y offset
        }

        // Update field colors
        offsetXField.textColor = wouldBeOffScreenX ? .systemRed : .labelColor
        offsetYField.textColor = wouldBeOffScreenY ? .systemRed : .labelColor
    }

    @objc private func autoStartChanged() {
        settings.autoStartMonitoring = autoStartCheckbox.state == .on
    }

    @objc private func launchAtLoginChanged() {
        settings.launchAtLogin = launchAtLoginCheckbox.state == .on
    }

    @objc private func exportSettings() {
        guard let window = self.window else {
            print("Export: No window available")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "notifymehow-settings-\(dateString).json"

        savePanel.beginSheetModal(for: window) { response in
            if response == .OK, let url = savePanel.url {
                if let data = self.settings.exportToJSON() {
                    do {
                        try data.write(to: url)
                    } catch {
                        print("Export failed: \(error)")
                    }
                }
            }
        }
    }

    @objc private func importSettings() {
        guard let window = self.window else {
            print("Import: No window available")
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        openPanel.beginSheetModal(for: window) { response in
            if response == .OK, let url = openPanel.url {
                if let data = try? Data(contentsOf: url) {
                    if self.settings.importFromJSON(data) {
                        self.loadSettings()
                        // Also reload other tabs
                        NotificationCenter.default.post(name: StylesManager.didChangeNotification, object: nil)
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Import Failed"
                        alert.informativeText = "Could not parse the settings file."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }
    }
}

