import Cocoa

/// Rules preferences tab - list of rules with add/remove/reorder
class RulesPreferencesView: NSView {
    private let rulesManager = RulesManager.shared

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var removeButton: NSButton!
    private var editButton: NSButton!
    private var moveUpButton: NSButton!
    private var moveDownButton: NSButton!
    private var defaultBehaviorPopup: NSPopUpButton!

    // Keep strong reference to editor window controller
    private var currentEditor: RuleEditorWindowController?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
        loadRules()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let padding: CGFloat = 15
        var y = frame.height - padding

        // Header
        y -= 20
        let header = createLabel("Notification Rules", bold: true)
        header.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        addSubview(header)

        let helpText = createLabel("Rules are evaluated in order. First match wins.")
        helpText.font = NSFont.systemFont(ofSize: 11)
        helpText.textColor = .secondaryLabelColor
        helpText.frame = NSRect(x: padding + 130, y: y, width: 250, height: 20)
        addSubview(helpText)

        // Table view
        y -= 145
        scrollView = NSScrollView(frame: NSRect(x: padding, y: y, width: frame.width - padding * 2, height: 140))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(editRule)
        tableView.target = self

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Rule Name"
        nameColumn.width = 180
        tableView.addTableColumn(nameColumn)

        let criteriaColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("criteria"))
        criteriaColumn.title = "Matches"
        criteriaColumn.width = 200
        tableView.addTableColumn(criteriaColumn)

        scrollView.documentView = tableView
        addSubview(scrollView)

        // Buttons below table
        y -= 30
        addButton = NSButton(title: "+", target: self, action: #selector(addRule))
        addButton.bezelStyle = .smallSquare
        addButton.frame = NSRect(x: padding, y: y, width: 24, height: 24)
        addSubview(addButton)

        removeButton = NSButton(title: "-", target: self, action: #selector(removeRule))
        removeButton.bezelStyle = .smallSquare
        removeButton.frame = NSRect(x: padding + 26, y: y, width: 24, height: 24)
        addSubview(removeButton)

        editButton = NSButton(title: "Edit...", target: self, action: #selector(editRule))
        editButton.bezelStyle = .rounded
        editButton.frame = NSRect(x: padding + 60, y: y - 2, width: 60, height: 24)
        addSubview(editButton)

        moveUpButton = NSButton(title: "▲", target: self, action: #selector(moveRuleUp))
        moveUpButton.bezelStyle = .smallSquare
        moveUpButton.frame = NSRect(x: frame.width - padding - 50, y: y, width: 24, height: 24)
        addSubview(moveUpButton)

        moveDownButton = NSButton(title: "▼", target: self, action: #selector(moveRuleDown))
        moveDownButton.bezelStyle = .smallSquare
        moveDownButton.frame = NSRect(x: frame.width - padding - 24, y: y, width: 24, height: 24)
        addSubview(moveDownButton)

        // Default behavior
        y -= 40
        let defaultLabel = createLabel("When no rules match:")
        defaultLabel.frame = NSRect(x: padding, y: y, width: 130, height: 22)
        addSubview(defaultLabel)

        defaultBehaviorPopup = NSPopUpButton(frame: NSRect(x: padding + 135, y: y, width: 220, height: 26), pullsDown: false)
        defaultBehaviorPopup.addItems(withTitles: [
            "Don't show custom notification",
            "Show custom notification (default style)"
        ])
        defaultBehaviorPopup.target = self
        defaultBehaviorPopup.action = #selector(defaultBehaviorChanged)
        addSubview(defaultBehaviorPopup)

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

    func loadRules() {
        tableView.reloadData()

        // Load default behavior
        switch rulesManager.defaultBehavior {
        case .noCustom:
            defaultBehaviorPopup.selectItem(at: 0)
        case .showCustom:
            defaultBehaviorPopup.selectItem(at: 1)
        }

        updateButtonStates()
    }

    private func updateButtonStates() {
        let hasSelection = tableView.selectedRow >= 0
        let count = rulesManager.rules.count

        removeButton.isEnabled = hasSelection
        editButton.isEnabled = hasSelection
        moveUpButton.isEnabled = hasSelection && tableView.selectedRow > 0
        moveDownButton.isEnabled = hasSelection && tableView.selectedRow < count - 1
    }

    // MARK: - Actions

    @objc private func addRule() {
        let newRule = NotificationRule()
        // Don't save yet - only save if user clicks Save in the editor
        currentEditor = RuleEditorWindowController(rule: newRule, isNew: true) { [weak self] savedRule in
            RulesManager.shared.addRule(savedRule)
            self?.tableView.reloadData()
            self?.updateButtonStates()
            self?.currentEditor = nil
        }
        currentEditor?.showWindow()
    }

    @objc private func removeRule() {
        let index = tableView.selectedRow
        guard index >= 0 else { return }

        rulesManager.deleteRule(at: index)
        tableView.reloadData()
        updateButtonStates()
    }

    @objc private func editRule() {
        let index = tableView.selectedRow
        guard index >= 0 && index < rulesManager.rules.count else { return }

        let rule = rulesManager.rules[index]
        currentEditor = RuleEditorWindowController(rule: rule, isNew: false) { [weak self] updatedRule in
            RulesManager.shared.updateRule(updatedRule)
            self?.tableView.reloadData()
            self?.currentEditor = nil
        }
        currentEditor?.showWindow()
    }

    @objc private func moveRuleUp() {
        let index = tableView.selectedRow
        guard index > 0 else { return }

        rulesManager.moveRule(from: index, to: index - 1)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
        updateButtonStates()
    }

    @objc private func moveRuleDown() {
        let index = tableView.selectedRow
        guard index >= 0 && index < rulesManager.rules.count - 1 else { return }

        rulesManager.moveRule(from: index, to: index + 1)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: index + 1), byExtendingSelection: false)
        updateButtonStates()
    }

    @objc private func defaultBehaviorChanged() {
        rulesManager.defaultBehavior = defaultBehaviorPopup.indexOfSelectedItem == 0 ? .noCustom : .showCustom
    }
}

// MARK: - NSTableViewDataSource

extension RulesPreferencesView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rulesManager.rules.count
    }
}

// MARK: - NSTableViewDelegate

extension RulesPreferencesView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rulesManager.rules.count else { return nil }
        let rule = rulesManager.rules[row]

        let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellIdentifier
        }

        if tableColumn?.identifier.rawValue == "name" {
            cell?.stringValue = rule.displayName
            if rule.styleId == nil {
                cell?.textColor = .secondaryLabelColor
            } else {
                cell?.textColor = .labelColor
            }
        } else if tableColumn?.identifier.rawValue == "criteria" {
            // Show style name or criteria summary
            if let style = rule.style {
                cell?.stringValue = "Style: \(style.name)"
            } else {
                cell?.stringValue = "No custom notification"
            }
            cell?.textColor = .secondaryLabelColor
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }

    private func describeCriteria(_ criteria: NotificationMatchCriteria) -> String {
        var parts: [String] = []

        if !criteria.appName.isEmpty {
            parts.append("App: \(criteria.appName)")
        }
        if !criteria.titleContains.isEmpty {
            parts.append("Title: \(criteria.titleContains)")
        }
        if !criteria.bodyContains.isEmpty {
            parts.append("Body: \(criteria.bodyContains)")
        }

        if parts.isEmpty {
            return "(matches all)"
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Rule Editor Window

class RuleEditorWindowController: NSWindowController {
    private var rule: NotificationRule
    private var onSave: (NotificationRule) -> Void

    // General
    private var nameField: NSTextField!

    // Criteria
    private var appNameField: NSTextField!
    private var titleContainsField: NSTextField!
    private var bodyContainsField: NSTextField!

    // Style selection
    private var stylePopup: NSPopUpButton!
    private var customStyleContainer: NSView!

    // Custom style controls (shown when "Custom..." is selected)
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
    private var subtitleColorWell: NSColorWell!
    private var bodyColorWell: NSColorWell!
    private var iconImageView: NSImageView!
    private var customIconPath: String? = nil
    private var bgImageView: NSImageView!
    private var backgroundImagePath: String? = nil
    private var showAppNameCheckbox: NSButton!

    // Track if we're editing a custom style
    private var isCustomStyle = false
    private var editingStyle: NotificationStyle?
    private var isNewRule: Bool

    init(rule: NotificationRule, isNew: Bool, onSave: @escaping (NotificationRule) -> Void) {
        self.rule = rule
        self.isNewRule = isNew
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 650),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = isNew ? "Add Rule" : "Edit Rule"
        window.center()

        super.init(window: window)

        setupUI()
        loadRule()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let padding: CGFloat = 20
        var y = contentView.frame.height - padding

        // Rule Name
        y -= 25
        let nameLabel = createLabel("Rule Name:", bold: true)
        nameLabel.frame = NSRect(x: padding, y: y, width: 100, height: 22)
        contentView.addSubview(nameLabel)

        nameField = NSTextField(frame: NSRect(x: padding + 100, y: y, width: 280, height: 22))
        nameField.placeholderString = "(auto-generated from criteria)"
        contentView.addSubview(nameField)

        // Match Criteria Section
        y -= 35
        let criteriaHeader = createLabel("Match Criteria (all must match)", bold: true)
        criteriaHeader.frame = NSRect(x: padding, y: y, width: 300, height: 20)
        contentView.addSubview(criteriaHeader)

        y -= 28
        let appLabel = createLabel("App name contains:")
        appLabel.frame = NSRect(x: padding, y: y, width: 130, height: 22)
        contentView.addSubview(appLabel)

        appNameField = NSTextField(frame: NSRect(x: padding + 135, y: y, width: 245, height: 22))
        appNameField.placeholderString = "e.g., Messages, Slack"
        contentView.addSubview(appNameField)

        y -= 28
        let titleLabel = createLabel("Title contains:")
        titleLabel.frame = NSRect(x: padding, y: y, width: 130, height: 22)
        contentView.addSubview(titleLabel)

        titleContainsField = NSTextField(frame: NSRect(x: padding + 135, y: y, width: 245, height: 22))
        titleContainsField.placeholderString = "e.g., John Smith"
        contentView.addSubview(titleContainsField)

        y -= 28
        let bodyLabel = createLabel("Body contains:")
        bodyLabel.frame = NSRect(x: padding, y: y, width: 130, height: 22)
        contentView.addSubview(bodyLabel)

        bodyContainsField = NSTextField(frame: NSRect(x: padding + 135, y: y, width: 245, height: 22))
        bodyContainsField.placeholderString = "e.g., meeting, urgent"
        contentView.addSubview(bodyContainsField)

        // Style Selection Section
        y -= 35
        let styleHeader = createLabel("Notification Style", bold: true)
        styleHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        contentView.addSubview(styleHeader)

        y -= 28
        let styleLabel = createLabel("Style:")
        styleLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        contentView.addSubview(styleLabel)

        stylePopup = NSPopUpButton(frame: NSRect(x: padding + 55, y: y, width: 200, height: 26), pullsDown: false)
        stylePopup.target = self
        stylePopup.action = #selector(styleSelectionChanged)
        contentView.addSubview(stylePopup)

        // Custom style container (initially hidden)
        y -= 10
        customStyleContainer = NSView(frame: NSRect(x: 0, y: 60, width: contentView.frame.width, height: y - 60))
        contentView.addSubview(customStyleContainer)

        setupCustomStyleControls()
        updateCustomStyleVisibility()

        // Buttons (always at bottom)
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: contentView.frame.width - padding - 170, y: 20, width: 80, height: 28)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: contentView.frame.width - padding - 80, y: 20, width: 80, height: 28)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
    }

    private func setupCustomStyleControls() {
        let padding: CGFloat = 20
        var y = customStyleContainer.frame.height - 10

        y -= 28
        let posLabel = createLabel("Position:")
        posLabel.frame = NSRect(x: padding, y: y, width: 80, height: 22)
        customStyleContainer.addSubview(posLabel)

        positionPopup = NSPopUpButton(frame: NSRect(x: padding + 85, y: y, width: 140, height: 26), pullsDown: false)
        positionPopup.addItems(withTitles: [
            "Top Left", "Top Center", "Top Right",
            "Middle Left", "Center", "Middle Right",
            "Bottom Left", "Bottom Center", "Bottom Right"
        ])
        customStyleContainer.addSubview(positionPopup)

        y -= 28
        let offsetLabel = createLabel("Offset:")
        offsetLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        customStyleContainer.addSubview(offsetLabel)

        let xLabel = createLabel("X:")
        xLabel.frame = NSRect(x: padding + 55, y: y, width: 20, height: 22)
        customStyleContainer.addSubview(xLabel)

        offsetXField = NSTextField(frame: NSRect(x: padding + 75, y: y, width: 45, height: 22))
        customStyleContainer.addSubview(offsetXField)

        let yLabel = createLabel("Y:")
        yLabel.frame = NSRect(x: padding + 130, y: y, width: 20, height: 22)
        customStyleContainer.addSubview(yLabel)

        offsetYField = NSTextField(frame: NSRect(x: padding + 150, y: y, width: 45, height: 22))
        customStyleContainer.addSubview(offsetYField)

        y -= 28
        let scaleTextLabel = createLabel("Scale:")
        scaleTextLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        customStyleContainer.addSubview(scaleTextLabel)

        scaleSlider = NSSlider(frame: NSRect(x: padding + 55, y: y, width: 150, height: 22))
        scaleSlider.minValue = 0.5
        scaleSlider.maxValue = 3.0
        scaleSlider.target = self
        scaleSlider.action = #selector(scaleChanged)
        customStyleContainer.addSubview(scaleSlider)

        scaleLabel = createLabel("1.5x")
        scaleLabel.frame = NSRect(x: padding + 210, y: y, width: 40, height: 22)
        customStyleContainer.addSubview(scaleLabel)

        y -= 28
        let opacityTextLabel = createLabel("Opacity:")
        opacityTextLabel.frame = NSRect(x: padding, y: y, width: 55, height: 22)
        customStyleContainer.addSubview(opacityTextLabel)

        opacitySlider = NSSlider(frame: NSRect(x: padding + 55, y: y, width: 150, height: 22))
        opacitySlider.minValue = 0.1
        opacitySlider.maxValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        customStyleContainer.addSubview(opacitySlider)

        opacityLabel = createLabel("95%")
        opacityLabel.frame = NSRect(x: padding + 210, y: y, width: 40, height: 22)
        customStyleContainer.addSubview(opacityLabel)

        y -= 28
        let dwellLabel = createLabel("Display:")
        dwellLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        customStyleContainer.addSubview(dwellLabel)

        dwellField = NSTextField(frame: NSRect(x: padding + 55, y: y, width: 45, height: 22))
        customStyleContainer.addSubview(dwellField)

        let secLabel = createLabel("seconds")
        secLabel.frame = NSRect(x: padding + 105, y: y, width: 55, height: 22)
        customStyleContainer.addSubview(secLabel)

        y -= 35
        let colorsLabel = createLabel("Colors:")
        colorsLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        customStyleContainer.addSubview(colorsLabel)

        let bgLabel = createLabel("BG")
        bgLabel.frame = NSRect(x: padding + 55, y: y, width: 22, height: 22)
        customStyleContainer.addSubview(bgLabel)

        bgColorWell = NSColorWell(frame: NSRect(x: padding + 77, y: y, width: 32, height: 22))
        customStyleContainer.addSubview(bgColorWell)

        let titleCLabel = createLabel("Title")
        titleCLabel.frame = NSRect(x: padding + 120, y: y, width: 30, height: 22)
        customStyleContainer.addSubview(titleCLabel)

        titleColorWell = NSColorWell(frame: NSRect(x: padding + 152, y: y, width: 32, height: 22))
        customStyleContainer.addSubview(titleColorWell)

        let subtitleCLabel = createLabel("Subtitle")
        subtitleCLabel.frame = NSRect(x: padding + 195, y: y, width: 45, height: 22)
        customStyleContainer.addSubview(subtitleCLabel)

        subtitleColorWell = NSColorWell(frame: NSRect(x: padding + 242, y: y, width: 32, height: 22))
        customStyleContainer.addSubview(subtitleColorWell)

        let bodyCLabel = createLabel("Body")
        bodyCLabel.frame = NSRect(x: padding + 285, y: y, width: 32, height: 22)
        customStyleContainer.addSubview(bodyCLabel)

        bodyColorWell = NSColorWell(frame: NSRect(x: padding + 319, y: y, width: 32, height: 22))
        customStyleContainer.addSubview(bodyColorWell)

        // App name row: checkbox + color
        y -= 35
        showAppNameCheckbox = NSButton(checkboxWithTitle: "Show app name", target: nil, action: nil)
        showAppNameCheckbox.frame = NSRect(x: padding, y: y, width: 130, height: 20)
        customStyleContainer.addSubview(showAppNameCheckbox)

        let appCLabel = createLabel("App Color:")
        appCLabel.frame = NSRect(x: padding + 140, y: y, width: 65, height: 22)
        customStyleContainer.addSubview(appCLabel)

        appColorWell = NSColorWell(frame: NSRect(x: padding + 205, y: y, width: 32, height: 22))
        customStyleContainer.addSubview(appColorWell)

        // Custom Icon
        y -= 45
        let iconLabel = createLabel("Custom Icon:")
        iconLabel.frame = NSRect(x: padding, y: y, width: 85, height: 22)
        customStyleContainer.addSubview(iconLabel)

        iconImageView = NSImageView(frame: NSRect(x: padding + 90, y: y - 10, width: 40, height: 40))
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 20
        iconImageView.layer?.masksToBounds = true
        iconImageView.layer?.borderWidth = 1
        iconImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        customStyleContainer.addSubview(iconImageView)

        let chooseButton = NSButton(title: "Choose...", target: self, action: #selector(chooseIcon))
        chooseButton.bezelStyle = .rounded
        chooseButton.frame = NSRect(x: padding + 140, y: y - 2, width: 80, height: 24)
        customStyleContainer.addSubview(chooseButton)

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearIcon))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: padding + 225, y: y - 2, width: 60, height: 24)
        customStyleContainer.addSubview(clearButton)

        let iconHint = createLabel("Square recommended (e.g. 128x128)")
        iconHint.font = NSFont.systemFont(ofSize: 10)
        iconHint.textColor = .secondaryLabelColor
        iconHint.frame = NSRect(x: padding + 90, y: y - 30, width: 200, height: 14)
        customStyleContainer.addSubview(iconHint)

        // Background Image
        y -= 60
        let bgImageLabel = createLabel("Background:")
        bgImageLabel.frame = NSRect(x: padding, y: y, width: 85, height: 22)
        customStyleContainer.addSubview(bgImageLabel)

        bgImageView = NSImageView(frame: NSRect(x: padding + 90, y: y - 10, width: 60, height: 40))
        bgImageView.imageScaling = .scaleProportionallyUpOrDown
        bgImageView.wantsLayer = true
        bgImageView.layer?.cornerRadius = 4
        bgImageView.layer?.masksToBounds = true
        bgImageView.layer?.borderWidth = 1
        bgImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        customStyleContainer.addSubview(bgImageView)

        let chooseBgButton = NSButton(title: "Choose...", target: self, action: #selector(chooseBackgroundImage))
        chooseBgButton.bezelStyle = .rounded
        chooseBgButton.frame = NSRect(x: padding + 160, y: y - 2, width: 80, height: 24)
        customStyleContainer.addSubview(chooseBgButton)

        let clearBgButton = NSButton(title: "Clear", target: self, action: #selector(clearBackgroundImage))
        clearBgButton.bezelStyle = .rounded
        clearBgButton.frame = NSRect(x: padding + 245, y: y - 2, width: 60, height: 24)
        customStyleContainer.addSubview(clearBgButton)

        let bgHint = createLabel("16:9 or wider recommended")
        bgHint.font = NSFont.systemFont(ofSize: 10)
        bgHint.textColor = .secondaryLabelColor
        bgHint.frame = NSRect(x: padding + 90, y: y - 30, width: 200, height: 14)
        customStyleContainer.addSubview(bgHint)

        // Set defaults
        loadDefaultStyleValues()
    }

    private func loadDefaultStyleValues() {
        let defaultStyle = NotificationStyle()
        positionPopup.selectItem(at: cornerToIndex(defaultStyle.position))
        offsetXField.stringValue = String(Int(defaultStyle.offsetX))
        offsetYField.stringValue = String(Int(defaultStyle.offsetY))
        scaleSlider.doubleValue = defaultStyle.scale
        scaleLabel.stringValue = String(format: "%.1fx", defaultStyle.scale)
        opacitySlider.doubleValue = defaultStyle.opacity
        opacityLabel.stringValue = String(format: "%.0f%%", defaultStyle.opacity * 100)
        dwellField.stringValue = String(Int(defaultStyle.dwellTime))
        bgColorWell.color = colorFromHex(defaultStyle.backgroundColorHex)
        appColorWell.color = colorFromHex(defaultStyle.appColorHex)
        titleColorWell.color = colorFromHex(defaultStyle.titleColorHex)
        subtitleColorWell.color = colorFromHex(defaultStyle.subtitleColorHex)
        bodyColorWell.color = colorFromHex(defaultStyle.bodyColorHex)
        customIconPath = nil
        iconImageView.image = nil
        backgroundImagePath = nil
        bgImageView.image = nil
    }

    private func loadStyleValues(_ style: NotificationStyle) {
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
        subtitleColorWell.color = colorFromHex(style.subtitleColorHex)
        bodyColorWell.color = colorFromHex(style.bodyColorHex)

        // Load custom icon
        customIconPath = style.customIconPath
        if let path = customIconPath, !path.isEmpty {
            iconImageView.image = NSImage(contentsOfFile: path)
        } else {
            iconImageView.image = nil
        }

        // Load background image
        backgroundImagePath = style.backgroundImagePath
        if let path = backgroundImagePath, !path.isEmpty {
            bgImageView.image = NSImage(contentsOfFile: path)
        } else {
            bgImageView.image = nil
        }

        // Load show app name setting
        showAppNameCheckbox.state = style.showAppName ? .on : .off
    }

    private func rebuildStylePopup() {
        stylePopup.removeAllItems()

        // First option: No custom notification
        stylePopup.addItem(withTitle: "No custom notification")

        // Add separator
        stylePopup.menu?.addItem(NSMenuItem.separator())

        // Add all saved styles
        for style in StylesManager.shared.styles {
            stylePopup.addItem(withTitle: style.name)
        }

        // Add separator and custom option
        stylePopup.menu?.addItem(NSMenuItem.separator())
        stylePopup.addItem(withTitle: "Custom...")
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

    private func loadRule() {
        nameField.stringValue = rule.name

        appNameField.stringValue = rule.criteria.appName
        titleContainsField.stringValue = rule.criteria.titleContains
        bodyContainsField.stringValue = rule.criteria.bodyContains

        rebuildStylePopup()

        // Select the appropriate style in the popup
        if let styleId = rule.styleId, let style = StylesManager.shared.style(withId: styleId) {
            // Find the style in the popup (offset by 2 for "No custom" + separator)
            if let index = StylesManager.shared.styles.firstIndex(where: { $0.id == styleId }) {
                stylePopup.selectItem(at: index + 2)  // +2 for "No custom" and separator
            }
            editingStyle = style
            loadStyleValues(style)
            isCustomStyle = true  // Show editor for existing style
        } else {
            // No style - select "No custom notification"
            stylePopup.selectItem(at: 0)
            isCustomStyle = false
        }

        updateCustomStyleVisibility()
    }

    @objc private func styleSelectionChanged() {
        let selectedIndex = stylePopup.indexOfSelectedItem
        let lastIndex = stylePopup.numberOfItems - 1

        if selectedIndex == 0 {
            // "No custom notification"
            isCustomStyle = false
            editingStyle = nil
        } else if selectedIndex == lastIndex {
            // "Custom..." - creating a brand new style
            isCustomStyle = true
            editingStyle = nil
            loadDefaultStyleValues()
        } else {
            // A saved style (accounting for separator) - allow editing
            let styleIndex = selectedIndex - 2
            if styleIndex >= 0 && styleIndex < StylesManager.shared.styles.count {
                let style = StylesManager.shared.styles[styleIndex]
                editingStyle = style
                loadStyleValues(style)
                isCustomStyle = true  // Show the editor so they can tweak it
            }
        }

        updateCustomStyleVisibility()
    }

    private func updateCustomStyleVisibility() {
        customStyleContainer.isHidden = !isCustomStyle
    }

    /// Check if the current style values differ from the original editingStyle
    private func styleWasModified() -> Bool {
        guard let original = editingStyle else { return true }  // New style = always "modified"

        if indexToCorner(positionPopup.indexOfSelectedItem) != original.position { return true }
        if (Double(offsetXField.stringValue) ?? 20) != original.offsetX { return true }
        if (Double(offsetYField.stringValue) ?? 20) != original.offsetY { return true }
        if scaleSlider.doubleValue != original.scale { return true }
        if opacitySlider.doubleValue != original.opacity { return true }
        if (Double(dwellField.stringValue) ?? 5) != original.dwellTime { return true }
        if hexFromColor(bgColorWell.color) != original.backgroundColorHex { return true }
        if hexFromColor(appColorWell.color) != original.appColorHex { return true }
        if hexFromColor(titleColorWell.color) != original.titleColorHex { return true }
        if hexFromColor(subtitleColorWell.color) != original.subtitleColorHex { return true }
        if hexFromColor(bodyColorWell.color) != original.bodyColorHex { return true }
        if customIconPath != original.customIconPath { return true }
        if backgroundImagePath != original.backgroundImagePath { return true }
        if (showAppNameCheckbox.state == .on) != original.showAppName { return true }

        return false
    }

    /// Build a NotificationStyle from the current form values
    private func buildStyleFromForm() -> NotificationStyle {
        var style = editingStyle ?? NotificationStyle()
        style.position = indexToCorner(positionPopup.indexOfSelectedItem)
        style.offsetX = Double(offsetXField.stringValue) ?? 20
        style.offsetY = Double(offsetYField.stringValue) ?? 20
        style.scale = scaleSlider.doubleValue
        style.opacity = opacitySlider.doubleValue
        style.dwellTime = Double(dwellField.stringValue) ?? 5
        style.backgroundColorHex = hexFromColor(bgColorWell.color)
        style.appColorHex = hexFromColor(appColorWell.color)
        style.titleColorHex = hexFromColor(titleColorWell.color)
        style.subtitleColorHex = hexFromColor(subtitleColorWell.color)
        style.bodyColorHex = hexFromColor(bodyColorWell.color)
        style.customIconPath = customIconPath
        style.backgroundImagePath = backgroundImagePath
        style.showAppName = showAppNameCheckbox.state == .on
        return style
    }

    @objc private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an icon image (recommended: square, e.g. 128x128)"

        guard let win = window else { return }
        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.customIconPath = url.path
                self?.iconImageView.image = NSImage(contentsOf: url)
            }
        }
    }

    @objc private func clearIcon() {
        customIconPath = nil
        iconImageView.image = nil
    }

    @objc private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a background image (recommended: 16:9 or wider)"

        guard let win = window else { return }
        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.backgroundImagePath = url.path
                self?.bgImageView.image = NSImage(contentsOf: url)
            }
        }
    }

    @objc private func clearBackgroundImage() {
        backgroundImagePath = nil
        bgImageView.image = nil
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
        // Save rule name (or leave empty for auto-generation)
        rule.name = nameField.stringValue

        // Save criteria
        rule.criteria.appName = appNameField.stringValue
        rule.criteria.titleContains = titleContainsField.stringValue
        rule.criteria.bodyContains = bodyContainsField.stringValue

        let selectedIndex = stylePopup.indexOfSelectedItem
        let lastIndex = stylePopup.numberOfItems - 1

        if selectedIndex == 0 {
            // "No custom notification"
            rule.styleId = nil
            finalizeSave()
        } else if selectedIndex == lastIndex {
            // "Custom..." - create a new style and save it
            var newStyle = buildStyleFromForm()
            newStyle.id = UUID()  // Ensure new ID
            newStyle.name = generateUniqueStyleName()
            StylesManager.shared.addStyle(newStyle)
            rule.styleId = newStyle.id
            finalizeSave()
        } else {
            // A saved style - check if modified
            let styleIndex = selectedIndex - 2
            guard styleIndex >= 0 && styleIndex < StylesManager.shared.styles.count else {
                finalizeSave()
                return
            }

            let originalStyle = StylesManager.shared.styles[styleIndex]
            rule.styleId = originalStyle.id

            // If style wasn't modified, just save the rule
            if !styleWasModified() {
                finalizeSave()
                return
            }

            // Style was modified - check if it's used by other rules
            let otherRulesCount = RulesManager.shared.countRulesUsing(styleId: originalStyle.id, excluding: rule.id)

            if otherRulesCount == 0 {
                // Only this rule uses it - just update the style
                var updatedStyle = buildStyleFromForm()
                updatedStyle.id = originalStyle.id
                updatedStyle.name = originalStyle.name
                StylesManager.shared.updateStyle(updatedStyle)
                finalizeSave()
            } else {
                // Other rules use this style - ask user what to do
                let alert = NSAlert()
                alert.messageText = "This style is shared"
                alert.informativeText = "The style \"\(originalStyle.name)\" is used by \(otherRulesCount) other rule\(otherRulesCount == 1 ? "" : "s"). What would you like to do?"
                alert.addButton(withTitle: "Update All")
                alert.addButton(withTitle: "Save as New Style")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Update all - modify the shared style
                    var updatedStyle = buildStyleFromForm()
                    updatedStyle.id = originalStyle.id
                    updatedStyle.name = originalStyle.name
                    StylesManager.shared.updateStyle(updatedStyle)
                    finalizeSave()
                } else if response == .alertSecondButtonReturn {
                    // Save as new style
                    var newStyle = buildStyleFromForm()
                    newStyle.id = UUID()
                    newStyle.name = generateUniqueStyleName()
                    StylesManager.shared.addStyle(newStyle)
                    rule.styleId = newStyle.id
                    finalizeSave()
                }
                // Cancel - do nothing, stay in editor
            }
        }
    }

    /// Generate a unique style name based on the rule's display name
    private func generateUniqueStyleName() -> String {
        let baseName = "Style for \(rule.displayName)"
        let existingNames = Set(StylesManager.shared.styles.map { $0.name })

        // If base name doesn't exist, use it
        if !existingNames.contains(baseName) {
            return baseName
        }

        // Otherwise, find the next available number
        var counter = 2
        while true {
            let candidateName = "\(baseName) \(counter)"
            if !existingNames.contains(candidateName) {
                return candidateName
            }
            counter += 1
        }
    }

    private func finalizeSave() {
        onSave(rule)
        window?.orderOut(nil)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
