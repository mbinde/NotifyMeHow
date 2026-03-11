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
        return UIHelpers.createLabel(text, bold: bold)
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

    /// Open the rule editor with a pre-filled rule (called from Recent tab)
    func openEditorWithRule(_ rule: NotificationRule) {
        currentEditor = RuleEditorWindowController(rule: rule, isNew: true) { [weak self] savedRule in
            RulesManager.shared.addRule(savedRule)
            self?.tableView.reloadData()
            self?.updateButtonStates()
            self?.currentEditor = nil
        }
        currentEditor?.showWindow()
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
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cellView?.addSubview(textField)
            cellView?.textField = textField

            // Center vertically, pin to leading/trailing edges
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        let textField = cellView?.textField

        if tableColumn?.identifier.rawValue == "name" {
            textField?.stringValue = rule.displayName
            if rule.styleId == nil {
                textField?.textColor = .secondaryLabelColor
            } else {
                textField?.textColor = .labelColor
            }
        } else if tableColumn?.identifier.rawValue == "criteria" {
            // Show style name or criteria summary
            if let style = rule.style {
                textField?.stringValue = "Style: \(style.name)"
            } else {
                textField?.stringValue = "No custom notification"
            }
            textField?.textColor = .secondaryLabelColor
        }

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }

    private func describeCriteria(_ criteria: NotificationMatchCriteria) -> String {
        var parts: [String] = []

        if !criteria.appName.isEmpty {
            parts.append("App: \(criteria.appName)")
        }
        if !criteria.keywords.isEmpty {
            let matchType = criteria.matchAll ? "all" : "any"
            parts.append("Keywords (\(matchType)): \(criteria.keywords)")
        }

        if parts.isEmpty {
            return "(matches all)"
        }
        return parts.joined(separator: ", ")
    }
}
