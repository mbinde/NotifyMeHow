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
            textField?.stringValue = style.name
            textField?.textColor = .labelColor
        } else if tableColumn?.identifier.rawValue == "preview" {
            textField?.stringValue = describeStyle(style)
            textField?.textColor = .secondaryLabelColor
        }

        return cellView
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
    private var styleControlsView: StyleControlsView!

    init(style: NotificationStyle, onSave: @escaping (NotificationStyle) -> Void) {
        self.style = style
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
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

        // Style Name at top
        let nameLabel = NSTextField(labelWithString: "Style Name:")
        nameLabel.font = NSFont.boldSystemFont(ofSize: 12)
        nameLabel.frame = NSRect(x: padding, y: contentView.frame.height - 35, width: 100, height: 22)
        contentView.addSubview(nameLabel)

        nameField = NSTextField(frame: NSRect(x: padding + 100, y: contentView.frame.height - 35, width: 260, height: 22))
        contentView.addSubview(nameField)

        // Style controls view (all the shared controls)
        styleControlsView = StyleControlsView(frame: NSRect(x: 0, y: 60, width: contentView.frame.width, height: contentView.frame.height - 110))
        styleControlsView.parentWindow = window
        contentView.addSubview(styleControlsView)

        // Buttons at bottom
        let previewButton = NSButton(title: "Preview", target: self, action: #selector(preview))
        previewButton.bezelStyle = .rounded
        previewButton.frame = NSRect(x: padding, y: 20, width: 80, height: 28)
        contentView.addSubview(previewButton)

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

    @objc private func preview() {
        styleControlsView.showPreview()
    }

    private func loadStyle() {
        nameField.stringValue = style.name
        styleControlsView.style = style
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }

    @objc private func save() {
        // Get values from controls
        var updatedStyle = styleControlsView.style
        updatedStyle.id = style.id  // Preserve original ID
        updatedStyle.name = nameField.stringValue.isEmpty ? "Unnamed Style" : nameField.stringValue

        onSave(updatedStyle)
        window?.orderOut(nil)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
