import Cocoa

/// Styles preferences tab - manage reusable notification styles
class StylesPreferencesView: NSView {
    private let stylesManager = StylesManager.shared

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var removeButton: NSButton!
    private var editButton: NSButton!
    private var duplicateButton: NSButton!

    // Keep strong reference to editor window controller
    private var currentEditor: StyleEditorWindowController?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
        loadStyles()

        NotificationCenter.default.addObserver(
            self, selector: #selector(stylesDidChange),
            name: StylesManager.didChangeNotification, object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        let padding: CGFloat = 15
        var y = frame.height - padding

        // Header
        y -= 20
        let header = createLabel("Notification Styles", bold: true)
        header.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        addSubview(header)

        let helpText = createLabel("Create reusable styles for your notification rules.")
        helpText.font = NSFont.systemFont(ofSize: 11)
        helpText.textColor = .secondaryLabelColor
        helpText.frame = NSRect(x: padding + 135, y: y, width: 300, height: 20)
        addSubview(helpText)

        // Table view
        y -= 160
        scrollView = NSScrollView(frame: NSRect(x: padding, y: y, width: frame.width - padding * 2, height: 155))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(editStyle)
        tableView.target = self

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Style Name"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)

        let previewColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
        previewColumn.title = "Preview"
        previewColumn.width = 250
        tableView.addTableColumn(previewColumn)

        scrollView.documentView = tableView
        addSubview(scrollView)

        // Buttons below table
        y -= 30
        addButton = NSButton(title: "+", target: self, action: #selector(addStyle))
        addButton.bezelStyle = .smallSquare
        addButton.frame = NSRect(x: padding, y: y, width: 24, height: 24)
        addSubview(addButton)

        removeButton = NSButton(title: "-", target: self, action: #selector(removeStyle))
        removeButton.bezelStyle = .smallSquare
        removeButton.frame = NSRect(x: padding + 26, y: y, width: 24, height: 24)
        addSubview(removeButton)

        editButton = NSButton(title: "Edit...", target: self, action: #selector(editStyle))
        editButton.bezelStyle = .rounded
        editButton.frame = NSRect(x: padding + 60, y: y - 2, width: 60, height: 24)
        addSubview(editButton)

        duplicateButton = NSButton(title: "Duplicate", target: self, action: #selector(duplicateStyle))
        duplicateButton.bezelStyle = .rounded
        duplicateButton.frame = NSRect(x: padding + 130, y: y - 2, width: 80, height: 24)
        addSubview(duplicateButton)

        updateButtonStates()
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

    func loadStyles() {
        tableView.reloadData()
        updateButtonStates()
    }

    @objc private func stylesDidChange() {
        loadStyles()
    }

    private func updateButtonStates() {
        let hasSelection = tableView.selectedRow >= 0
        let count = stylesManager.styles.count

        // Can't remove if only one style left
        removeButton.isEnabled = hasSelection && count > 1
        editButton.isEnabled = hasSelection
        duplicateButton.isEnabled = hasSelection
    }

    // MARK: - Actions

    @objc private func addStyle() {
        var newStyle = NotificationStyle()
        newStyle.name = "New Style"
        stylesManager.addStyle(newStyle)
        tableView.reloadData()

        // Select and edit the new style
        let newIndex = stylesManager.styles.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        editStyle()
    }

    @objc private func removeStyle() {
        let index = tableView.selectedRow
        guard index >= 0 else { return }

        // Confirm deletion
        let alert = NSAlert()
        alert.messageText = "Delete Style?"
        alert.informativeText = "Rules using this style will no longer show custom notifications."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            stylesManager.deleteStyle(at: index)
            tableView.reloadData()
            updateButtonStates()
        }
    }

    @objc private func editStyle() {
        let index = tableView.selectedRow
        guard index >= 0 && index < stylesManager.styles.count else { return }

        let style = stylesManager.styles[index]
        currentEditor = StyleEditorWindowController(style: style) { [weak self] updatedStyle in
            StylesManager.shared.updateStyle(updatedStyle)
            self?.tableView.reloadData()
            self?.currentEditor = nil
        }
        currentEditor?.showWindow()
    }

    @objc private func duplicateStyle() {
        let index = tableView.selectedRow
        guard index >= 0 && index < stylesManager.styles.count else { return }

        var newStyle = stylesManager.styles[index]
        newStyle.id = UUID()
        newStyle.name = newStyle.name + " Copy"
        stylesManager.addStyle(newStyle)
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

extension StylesPreferencesView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return stylesManager.styles.count
    }
}

// MARK: - NSTableViewDelegate

extension StylesPreferencesView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < stylesManager.styles.count else { return nil }
        let style = stylesManager.styles[row]

        let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellIdentifier
        }

        if tableColumn?.identifier.rawValue == "name" {
            cell?.stringValue = style.name
            cell?.textColor = .labelColor
        } else if tableColumn?.identifier.rawValue == "preview" {
            cell?.stringValue = describeStyle(style)
            cell?.textColor = .secondaryLabelColor
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }

    private func describeStyle(_ style: NotificationStyle) -> String {
        let position = style.position.replacingOccurrences(of: "Left", with: " Left")
            .replacingOccurrences(of: "Right", with: " Right")
            .replacingOccurrences(of: "Center", with: " Center")
            .replacingOccurrences(of: "top", with: "Top")
            .replacingOccurrences(of: "middle", with: "Middle")
            .replacingOccurrences(of: "bottom", with: "Bottom")

        return "\(position), \(String(format: "%.1fx", style.scale)), \(Int(style.opacity * 100))%"
    }
}

// MARK: - Style Editor Window

class StyleEditorWindowController: NSWindowController {
    private var style: NotificationStyle
    private var onSave: (NotificationStyle) -> Void

    private var nameField: NSTextField!
    private var positionPopup: NSPopUpButton!
    private var offsetXField: NSTextField!
    private var offsetYField: NSTextField!
    private var scaleSlider: NSSlider!
    private var scaleLabel: NSTextField!
    private var opacitySlider: NSSlider!
    private var opacityLabel: NSTextField!
    private var dwellField: NSTextField!
    private var bgColorWell: NSColorWell!
    private var appColorWell: NSColorWell!
    private var titleColorWell: NSColorWell!
    private var bodyColorWell: NSColorWell!

    init(style: NotificationStyle, onSave: @escaping (NotificationStyle) -> Void) {
        self.style = style
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Style"
        window.center()

        super.init(window: window)

        setupUI()
        loadStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let padding: CGFloat = 20
        var y = contentView.frame.height - padding

        // Style Name
        y -= 25
        let nameLabel = createLabel("Style Name:", bold: true)
        nameLabel.frame = NSRect(x: padding, y: y, width: 100, height: 22)
        contentView.addSubview(nameLabel)

        nameField = NSTextField(frame: NSRect(x: padding + 100, y: y, width: 260, height: 22))
        contentView.addSubview(nameField)

        // Position
        y -= 35
        let posLabel = createLabel("Position:")
        posLabel.frame = NSRect(x: padding, y: y, width: 80, height: 22)
        contentView.addSubview(posLabel)

        positionPopup = NSPopUpButton(frame: NSRect(x: padding + 85, y: y, width: 140, height: 26), pullsDown: false)
        positionPopup.addItems(withTitles: [
            "Top Left", "Top Center", "Top Right",
            "Middle Left", "Center", "Middle Right",
            "Bottom Left", "Bottom Center", "Bottom Right"
        ])
        contentView.addSubview(positionPopup)

        // Offset
        y -= 30
        let offsetLabel = createLabel("Offset:")
        offsetLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        contentView.addSubview(offsetLabel)

        let xLabel = createLabel("X:")
        xLabel.frame = NSRect(x: padding + 55, y: y, width: 20, height: 22)
        contentView.addSubview(xLabel)

        offsetXField = NSTextField(frame: NSRect(x: padding + 75, y: y, width: 45, height: 22))
        contentView.addSubview(offsetXField)

        let yLabel = createLabel("Y:")
        yLabel.frame = NSRect(x: padding + 130, y: y, width: 20, height: 22)
        contentView.addSubview(yLabel)

        offsetYField = NSTextField(frame: NSRect(x: padding + 150, y: y, width: 45, height: 22))
        contentView.addSubview(offsetYField)

        let pxLabel = createLabel("px")
        pxLabel.frame = NSRect(x: padding + 200, y: y, width: 20, height: 22)
        contentView.addSubview(pxLabel)

        // Scale
        y -= 30
        let scaleTextLabel = createLabel("Scale:")
        scaleTextLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        contentView.addSubview(scaleTextLabel)

        scaleSlider = NSSlider(frame: NSRect(x: padding + 55, y: y, width: 180, height: 22))
        scaleSlider.minValue = 0.5
        scaleSlider.maxValue = 3.0
        scaleSlider.target = self
        scaleSlider.action = #selector(scaleChanged)
        contentView.addSubview(scaleSlider)

        scaleLabel = createLabel("1.5x")
        scaleLabel.frame = NSRect(x: padding + 240, y: y, width: 40, height: 22)
        contentView.addSubview(scaleLabel)

        // Opacity
        y -= 30
        let opacityTextLabel = createLabel("Opacity:")
        opacityTextLabel.frame = NSRect(x: padding, y: y, width: 55, height: 22)
        contentView.addSubview(opacityTextLabel)

        opacitySlider = NSSlider(frame: NSRect(x: padding + 55, y: y, width: 180, height: 22))
        opacitySlider.minValue = 0.1
        opacitySlider.maxValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        contentView.addSubview(opacitySlider)

        opacityLabel = createLabel("95%")
        opacityLabel.frame = NSRect(x: padding + 240, y: y, width: 40, height: 22)
        contentView.addSubview(opacityLabel)

        // Display time
        y -= 30
        let dwellLabel = createLabel("Display:")
        dwellLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        contentView.addSubview(dwellLabel)

        dwellField = NSTextField(frame: NSRect(x: padding + 55, y: y, width: 45, height: 22))
        contentView.addSubview(dwellField)

        let secLabel = createLabel("seconds")
        secLabel.frame = NSRect(x: padding + 105, y: y, width: 55, height: 22)
        contentView.addSubview(secLabel)

        // Colors
        y -= 35
        let colorsLabel = createLabel("Colors:")
        colorsLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        contentView.addSubview(colorsLabel)

        let bgLabel = createLabel("BG")
        bgLabel.frame = NSRect(x: padding + 55, y: y, width: 22, height: 22)
        contentView.addSubview(bgLabel)

        bgColorWell = NSColorWell(frame: NSRect(x: padding + 77, y: y, width: 32, height: 22))
        contentView.addSubview(bgColorWell)

        let appCLabel = createLabel("App")
        appCLabel.frame = NSRect(x: padding + 115, y: y, width: 28, height: 22)
        contentView.addSubview(appCLabel)

        appColorWell = NSColorWell(frame: NSRect(x: padding + 143, y: y, width: 32, height: 22))
        contentView.addSubview(appColorWell)

        let titleCLabel = createLabel("Title")
        titleCLabel.frame = NSRect(x: padding + 181, y: y, width: 30, height: 22)
        contentView.addSubview(titleCLabel)

        titleColorWell = NSColorWell(frame: NSRect(x: padding + 213, y: y, width: 32, height: 22))
        contentView.addSubview(titleColorWell)

        let bodyCLabel = createLabel("Body")
        bodyCLabel.frame = NSRect(x: padding + 251, y: y, width: 32, height: 22)
        contentView.addSubview(bodyCLabel)

        bodyColorWell = NSColorWell(frame: NSRect(x: padding + 285, y: y, width: 32, height: 22))
        contentView.addSubview(bodyColorWell)

        // Buttons
        y -= 50
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: contentView.frame.width - padding - 170, y: y, width: 80, height: 28)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: contentView.frame.width - padding - 80, y: y, width: 80, height: 28)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
    }

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 12)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    private func loadStyle() {
        nameField.stringValue = style.name
        positionPopup.selectItem(at: cornerToIndex(style.position))
        offsetXField.stringValue = String(Int(style.offsetX))
        offsetYField.stringValue = String(Int(style.offsetY))
        scaleSlider.doubleValue = style.scale
        scaleLabel.stringValue = String(format: "%.1fx", style.scale)
        opacitySlider.doubleValue = style.opacity
        opacityLabel.stringValue = String(format: "%.0f%%", style.opacity * 100)
        dwellField.stringValue = String(Int(style.dwellTime))

        bgColorWell.color = colorFromHex(style.backgroundColorHex)
        appColorWell.color = colorFromHex(style.appColorHex)
        titleColorWell.color = colorFromHex(style.titleColorHex)
        bodyColorWell.color = colorFromHex(style.bodyColorHex)
    }

    private func cornerToIndex(_ corner: String) -> Int {
        switch corner {
        case "topLeft": return 0
        case "topCenter": return 1
        case "topRight": return 2
        case "middleLeft": return 3
        case "center": return 4
        case "middleRight": return 5
        case "bottomLeft": return 6
        case "bottomCenter": return 7
        case "bottomRight": return 8
        default: return 6
        }
    }

    private func indexToCorner(_ index: Int) -> String {
        switch index {
        case 0: return "topLeft"
        case 1: return "topCenter"
        case 2: return "topRight"
        case 3: return "middleLeft"
        case 4: return "center"
        case 5: return "middleRight"
        case 6: return "bottomLeft"
        case 7: return "bottomCenter"
        case 8: return "bottomRight"
        default: return "bottomLeft"
        }
    }

    private func colorFromHex(_ hex: String) -> NSColor {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleanHex.count == 6 else { return .black }

        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func hexFromColor(_ color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return "000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    @objc private func scaleChanged() {
        scaleLabel.stringValue = String(format: "%.1fx", scaleSlider.doubleValue)
    }

    @objc private func opacityChanged() {
        opacityLabel.stringValue = String(format: "%.0f%%", opacitySlider.doubleValue * 100)
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }

    @objc private func save() {
        style.name = nameField.stringValue.isEmpty ? "Unnamed Style" : nameField.stringValue
        style.position = indexToCorner(positionPopup.indexOfSelectedItem)
        style.offsetX = Double(offsetXField.stringValue) ?? 20
        style.offsetY = Double(offsetYField.stringValue) ?? 20
        style.scale = scaleSlider.doubleValue
        style.opacity = opacitySlider.doubleValue
        style.dwellTime = Double(dwellField.stringValue) ?? 5

        style.backgroundColorHex = hexFromColor(bgColorWell.color)
        style.appColorHex = hexFromColor(appColorWell.color)
        style.titleColorHex = hexFromColor(titleColorWell.color)
        style.bodyColorHex = hexFromColor(bodyColorWell.color)

        onSave(style)
        window?.orderOut(nil)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
