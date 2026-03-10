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

        // Listen for style changes to refresh the table
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

    @objc private func stylesDidChange() {
        tableView.reloadData()
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
    private var styleControlsView: StyleControlsView!

    // Track if we're editing a custom style
    private var isCustomStyle = false
    private var editingStyle: NotificationStyle?
    private var isNewRule: Bool

    init(rule: NotificationRule, isNew: Bool, onSave: @escaping (NotificationRule) -> Void) {
        self.rule = rule
        self.isNewRule = isNew
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 590),
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

        // Custom style container with StyleControlsView
        y -= 10
        customStyleContainer = NSView(frame: NSRect(x: 0, y: 60, width: contentView.frame.width, height: y - 60))
        contentView.addSubview(customStyleContainer)

        styleControlsView = StyleControlsView(frame: NSRect(x: 0, y: 0, width: customStyleContainer.frame.width, height: customStyleContainer.frame.height))
        styleControlsView.parentWindow = window
        customStyleContainer.addSubview(styleControlsView)

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

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 12)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
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
            styleControlsView.style = style
            isCustomStyle = true
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
            styleControlsView.style = NotificationStyle()
        } else {
            // A saved style (accounting for separator) - allow editing
            let styleIndex = selectedIndex - 2
            if styleIndex >= 0 && styleIndex < StylesManager.shared.styles.count {
                let style = StylesManager.shared.styles[styleIndex]
                editingStyle = style
                styleControlsView.style = style
                isCustomStyle = true
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

        let current = styleControlsView.style
        if current.position != original.position { return true }
        if current.offsetX != original.offsetX { return true }
        if current.offsetY != original.offsetY { return true }
        if current.scale != original.scale { return true }
        if current.opacity != original.opacity { return true }
        if current.dwellTime != original.dwellTime { return true }
        if current.backgroundColorHex != original.backgroundColorHex { return true }
        if current.appColorHex != original.appColorHex { return true }
        if current.titleColorHex != original.titleColorHex { return true }
        if current.subtitleColorHex != original.subtitleColorHex { return true }
        if current.bodyColorHex != original.bodyColorHex { return true }
        if current.customIconPath != original.customIconPath { return true }
        if current.backgroundImagePath != original.backgroundImagePath { return true }
        if current.showAppName != original.showAppName { return true }
        if current.borderWidth != original.borderWidth { return true }
        if current.borderColorHex != original.borderColorHex { return true }
        if current.animation != original.animation { return true }

        return false
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
            var newStyle = styleControlsView.style
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
                var updatedStyle = styleControlsView.style
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
                    var updatedStyle = styleControlsView.style
                    updatedStyle.id = originalStyle.id
                    updatedStyle.name = originalStyle.name
                    StylesManager.shared.updateStyle(updatedStyle)
                    finalizeSave()
                } else if response == .alertSecondButtonReturn {
                    // Save as new style
                    var newStyle = styleControlsView.style
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
