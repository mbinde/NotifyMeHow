import Cocoa

/// Window controller for editing a notification rule
class RuleEditorWindowController: NSWindowController {
    private var rule: NotificationRule
    private var onSave: (NotificationRule) -> Void

    // General
    private var nameField: NSTextField!

    // Criteria
    private var appNameField: NSTextField!
    private var keywordsField: NSTextField!
    private var matchAnyRadio: NSButton!
    private var matchAllRadio: NSButton!

    // Style selection
    private var stylePopup: NSPopUpButton!
    private var editStyleButton: NSButton!

    // Keep reference to style editor
    private var styleEditor: StyleEditorWindowController?

    init(rule: NotificationRule, isNew: Bool, onSave: @escaping (NotificationRule) -> Void) {
        self.rule = rule
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
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
        nameLabel.frame = NSRect(x: padding, y: y + 2, width: 100, height: 22)
        contentView.addSubview(nameLabel)

        nameField = createTextField(placeholder: "(auto-generated from criteria)")
        nameField.frame = NSRect(x: padding + 100, y: y, width: 280, height: 24)
        contentView.addSubview(nameField)

        // Match Criteria Section
        y -= 35
        let criteriaHeader = createLabel("Match Criteria", bold: true)
        criteriaHeader.frame = NSRect(x: padding, y: y, width: 300, height: 20)
        contentView.addSubview(criteriaHeader)

        y -= 28
        let appLabel = createLabel("App name contains:")
        appLabel.frame = NSRect(x: padding, y: y + 2, width: 130, height: 22)
        contentView.addSubview(appLabel)

        appNameField = createTextField(placeholder: "e.g., Messages, Slack")
        appNameField.frame = NSRect(x: padding + 135, y: y, width: 245, height: 24)
        contentView.addSubview(appNameField)

        y -= 28
        let keywordsLabel = createLabel("Keywords:")
        keywordsLabel.frame = NSRect(x: padding, y: y + 2, width: 130, height: 22)
        contentView.addSubview(keywordsLabel)

        keywordsField = createTextField(placeholder: "e.g., urgent, meeting, John")
        keywordsField.frame = NSRect(x: padding + 135, y: y, width: 245, height: 24)
        contentView.addSubview(keywordsField)

        y -= 22
        let keywordsHint = createLabel("Comma-separated. Searches title, subtitle, and body.")
        keywordsHint.font = NSFont.systemFont(ofSize: 10)
        keywordsHint.textColor = .secondaryLabelColor
        keywordsHint.frame = NSRect(x: padding + 135, y: y, width: 245, height: 16)
        contentView.addSubview(keywordsHint)

        y -= 24
        let matchLabel = createLabel("Match:")
        matchLabel.frame = NSRect(x: padding, y: y + 2, width: 130, height: 22)
        contentView.addSubview(matchLabel)

        matchAnyRadio = NSButton(radioButtonWithTitle: "Any keyword", target: nil, action: nil)
        matchAnyRadio.frame = NSRect(x: padding + 135, y: y, width: 100, height: 22)
        contentView.addSubview(matchAnyRadio)

        matchAllRadio = NSButton(radioButtonWithTitle: "All keywords", target: nil, action: nil)
        matchAllRadio.frame = NSRect(x: padding + 245, y: y, width: 110, height: 22)
        contentView.addSubview(matchAllRadio)

        // Style Selection Section
        y -= 35
        let styleHeader = createLabel("Notification Style", bold: true)
        styleHeader.frame = NSRect(x: padding, y: y, width: 200, height: 20)
        contentView.addSubview(styleHeader)

        y -= 28
        let styleLabel = createLabel("Style:")
        styleLabel.frame = NSRect(x: padding, y: y + 3, width: 50, height: 22)
        contentView.addSubview(styleLabel)

        stylePopup = NSPopUpButton(frame: NSRect(x: padding + 55, y: y, width: 200, height: 26), pullsDown: false)
        stylePopup.target = self
        stylePopup.action = #selector(styleSelectionChanged)
        contentView.addSubview(stylePopup)

        editStyleButton = NSButton(title: "Edit...", target: self, action: #selector(editSelectedStyle))
        editStyleButton.bezelStyle = .rounded
        editStyleButton.frame = NSRect(x: padding + 265, y: y, width: 60, height: 26)
        contentView.addSubview(editStyleButton)

        // Buttons at bottom
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
        return UIHelpers.createLabel(text, bold: bold)
    }

    private func createTextField(placeholder: String) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.drawsBackground = true
        field.isBordered = true
        field.wantsLayer = true
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor.separatorColor.cgColor
        field.layer?.cornerRadius = 5
        field.backgroundColor = NSColor.controlBackgroundColor
        return field
    }

    private func rebuildStylePopup(selectingStyleId: UUID? = nil) {
        stylePopup.removeAllItems()

        // First option: No custom notification
        stylePopup.addItem(withTitle: "No custom notification")

        // Add separator
        stylePopup.menu?.addItem(NSMenuItem.separator())

        // Add all saved styles
        for style in StylesManager.shared.styles {
            stylePopup.addItem(withTitle: style.name)
        }

        // Add separator and create new option
        stylePopup.menu?.addItem(NSMenuItem.separator())
        stylePopup.addItem(withTitle: "Create New Style...")

        // Select the appropriate item
        if let styleId = selectingStyleId,
           let index = StylesManager.shared.styles.firstIndex(where: { $0.id == styleId }) {
            stylePopup.selectItem(at: index + 2)  // +2 for "No custom" and separator
        }

        updateEditButtonState()
    }

    private func loadRule() {
        nameField.stringValue = rule.name

        appNameField.stringValue = rule.criteria.appName

        // Load keywords - prefer new field, fall back to legacy fields
        if !rule.criteria.keywords.isEmpty {
            keywordsField.stringValue = rule.criteria.keywords
        } else {
            // Migrate from legacy fields
            var legacyKeywords: [String] = []
            if !rule.criteria.titleContains.isEmpty {
                legacyKeywords.append(rule.criteria.titleContains)
            }
            if !rule.criteria.bodyContains.isEmpty {
                legacyKeywords.append(rule.criteria.bodyContains)
            }
            keywordsField.stringValue = legacyKeywords.joined(separator: ", ")
        }

        // Set radio buttons
        if rule.criteria.matchAll {
            matchAllRadio.state = .on
            matchAnyRadio.state = .off
        } else {
            matchAnyRadio.state = .on
            matchAllRadio.state = .off
        }

        rebuildStylePopup(selectingStyleId: rule.styleId)

        // If no style selected, select "No custom notification"
        if rule.styleId == nil {
            stylePopup.selectItem(at: 0)
        }

        updateEditButtonState()
    }

    @objc private func styleSelectionChanged() {
        let selectedIndex = stylePopup.indexOfSelectedItem
        let lastIndex = stylePopup.numberOfItems - 1

        if selectedIndex == lastIndex {
            // "Create New Style..." - open style editor with new style
            var newStyle = NotificationStyle()
            newStyle.name = generateUniqueStyleName()

            styleEditor = StyleEditorWindowController(style: newStyle) { [weak self] savedStyle in
                StylesManager.shared.addStyle(savedStyle)
                self?.rebuildStylePopup(selectingStyleId: savedStyle.id)
                self?.styleEditor = nil
            }
            styleEditor?.showWindow()

            // Reset popup to previous selection while editor is open
            if let currentStyleId = rule.styleId,
               let index = StylesManager.shared.styles.firstIndex(where: { $0.id == currentStyleId }) {
                stylePopup.selectItem(at: index + 2)
            } else {
                stylePopup.selectItem(at: 0)
            }
        }

        updateEditButtonState()
    }

    private func updateEditButtonState() {
        let selectedIndex = stylePopup.indexOfSelectedItem
        let lastIndex = stylePopup.numberOfItems - 1
        // Enable edit button only for saved styles (not "No custom" or "Create New...")
        editStyleButton.isEnabled = selectedIndex > 0 && selectedIndex < lastIndex
    }

    @objc private func editSelectedStyle() {
        let selectedIndex = stylePopup.indexOfSelectedItem
        let styleIndex = selectedIndex - 2  // Account for "No custom" and separator

        guard styleIndex >= 0 && styleIndex < StylesManager.shared.styles.count else { return }

        let style = StylesManager.shared.styles[styleIndex]

        styleEditor = StyleEditorWindowController(style: style) { [weak self] updatedStyle in
            StylesManager.shared.updateStyle(updatedStyle)
            self?.rebuildStylePopup(selectingStyleId: updatedStyle.id)
            self?.styleEditor = nil
        }
        styleEditor?.showWindow()
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }

    @objc private func save() {
        // Save rule name (or leave empty for auto-generation)
        rule.name = nameField.stringValue

        // Save criteria
        rule.criteria.appName = appNameField.stringValue
        rule.criteria.keywords = keywordsField.stringValue
        rule.criteria.matchAll = matchAllRadio.state == .on
        // Clear legacy fields when saving
        rule.criteria.titleContains = ""
        rule.criteria.bodyContains = ""

        let selectedIndex = stylePopup.indexOfSelectedItem
        let lastIndex = stylePopup.numberOfItems - 1

        if selectedIndex == 0 || selectedIndex == lastIndex {
            // "No custom notification" or "Create New..." (user didn't finish creating)
            rule.styleId = nil
        } else {
            // A saved style
            let styleIndex = selectedIndex - 2
            if styleIndex >= 0 && styleIndex < StylesManager.shared.styles.count {
                rule.styleId = StylesManager.shared.styles[styleIndex].id
            } else {
                rule.styleId = nil
            }
        }

        onSave(rule)
        window?.orderOut(nil)
    }

    /// Generate a unique style name based on the rule's display name
    private func generateUniqueStyleName() -> String {
        // Use rule criteria to generate name, or fall back to generic
        var baseName: String
        if !appNameField.stringValue.isEmpty {
            baseName = "Style for \(appNameField.stringValue)"
        } else if !keywordsField.stringValue.isEmpty {
            let firstKeyword = keywordsField.stringValue.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
            baseName = "Style for \(firstKeyword)"
        } else {
            baseName = "New Style"
        }

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

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
