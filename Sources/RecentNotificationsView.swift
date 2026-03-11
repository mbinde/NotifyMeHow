import Cocoa

/// View for displaying recent notifications and creating rules from them
class RecentNotificationsView: NSView {
    private let history = NotificationHistory.shared

    private var recordingToggle: NSButton!
    private var retentionPopup: NSPopUpButton!
    private var clearButton: NSButton!
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidChange),
            name: NotificationHistory.didChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        let padding: CGFloat = 20
        var y = frame.height - padding

        // Header row with controls
        y -= 25

        recordingToggle = NSButton(checkboxWithTitle: "Record notifications", target: self, action: #selector(toggleRecording))
        recordingToggle.frame = NSRect(x: padding, y: y, width: 150, height: 20)
        recordingToggle.state = history.isRecording ? .on : .off
        addSubview(recordingToggle)

        let retentionLabel = createLabel("Keep for:")
        retentionLabel.frame = NSRect(x: padding + 160, y: y + 2, width: 55, height: 18)
        addSubview(retentionLabel)

        retentionPopup = NSPopUpButton(frame: NSRect(x: padding + 215, y: y - 2, width: 80, height: 24), pullsDown: false)
        retentionPopup.addItems(withTitles: ["5 min", "15 min", "30 min", "60 min"])
        retentionPopup.target = self
        retentionPopup.action = #selector(retentionChanged)
        selectRetentionItem()
        addSubview(retentionPopup)

        clearButton = NSButton(title: "Clear All", target: self, action: #selector(clearAll))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: frame.width - padding - 80, y: y - 2, width: 70, height: 24)
        addSubview(clearButton)

        // Info labels
        y -= 22
        let infoLabel = createLabel("Double-click a notification to create a rule for it.")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: padding, y: y, width: 400, height: 16)
        addSubview(infoLabel)

        y -= 14
        let memoryLabel = createLabel("Notifications are stored in memory only and cleared when the app quits.")
        memoryLabel.font = NSFont.systemFont(ofSize: 11)
        memoryLabel.textColor = .tertiaryLabelColor
        memoryLabel.frame = NSRect(x: padding, y: y, width: 400, height: 16)
        addSubview(memoryLabel)

        // Table view
        y -= 10

        scrollView = NSScrollView(frame: NSRect(x: padding, y: padding, width: frame.width - padding * 2, height: y - padding))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 50
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClicked)

        // Columns
        let iconColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        iconColumn.title = ""
        iconColumn.width = 36
        iconColumn.minWidth = 36
        iconColumn.maxWidth = 36
        tableView.addTableColumn(iconColumn)

        let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        contentColumn.title = "Notification"
        contentColumn.width = 280
        contentColumn.minWidth = 200
        tableView.addTableColumn(contentColumn)

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 60
        timeColumn.minWidth = 50
        tableView.addTableColumn(timeColumn)

        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = ""
        actionColumn.width = 24
        actionColumn.minWidth = 24
        actionColumn.maxWidth = 24
        tableView.addTableColumn(actionColumn)

        scrollView.documentView = tableView
        addSubview(scrollView)
    }

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    private func selectRetentionItem() {
        switch history.retentionMinutes {
        case 5: retentionPopup.selectItem(at: 0)
        case 15: retentionPopup.selectItem(at: 1)
        case 30: retentionPopup.selectItem(at: 2)
        case 60: retentionPopup.selectItem(at: 3)
        default: retentionPopup.selectItem(at: 2)  // Default to 30
        }
    }

    func refresh() {
        recordingToggle.state = history.isRecording ? .on : .off
        selectRetentionItem()
        tableView.reloadData()
    }

    @objc private func historyDidChange() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @objc private func toggleRecording() {
        history.isRecording = recordingToggle.state == .on
    }

    @objc private func retentionChanged() {
        let minutes: Int
        switch retentionPopup.indexOfSelectedItem {
        case 0: minutes = 5
        case 1: minutes = 15
        case 2: minutes = 30
        case 3: minutes = 60
        default: minutes = 30
        }
        history.retentionMinutes = minutes
    }

    @objc private func clearAll() {
        history.clearAll()
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < history.notifications.count else { return }
        createRuleFromNotification(history.notifications[row])
    }

    @objc private func deleteNotification(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < history.notifications.count else { return }
        history.delete(history.notifications[row])
    }

    private func createRuleFromNotification(_ notification: RecordedNotification) {
        // Create a new rule pre-filled with this notification's info
        var rule = NotificationRule()
        rule.criteria.appName = notification.appName
        rule.criteria.keywords = notification.suggestedKeywords()

        // Open the rule editor with this pre-filled rule
        if let rulesView = findRulesView() {
            rulesView.openEditorWithRule(rule)
        }
    }

    private func findRulesView() -> RulesPreferencesView? {
        // Navigate up to find the tab view and get the rules tab
        var view: NSView? = self
        while let parent = view?.superview {
            if let tabView = parent as? NSTabView {
                for item in tabView.tabViewItems {
                    if let rulesView = item.view as? RulesPreferencesView {
                        tabView.selectTabViewItem(item)
                        return rulesView
                    }
                }
            }
            view = parent
        }
        return nil
    }
}

// MARK: - NSTableViewDataSource

extension RecentNotificationsView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return history.notifications.count
    }
}

// MARK: - NSTableViewDelegate

extension RecentNotificationsView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < history.notifications.count else { return nil }
        let notification = history.notifications[row]

        guard let columnId = tableColumn?.identifier.rawValue else { return nil }

        switch columnId {
        case "icon":
            let imageView = NSImageView(frame: NSRect(x: 4, y: 9, width: 32, height: 32))
            imageView.image = notification.appIcon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            let container = NSView()
            container.addSubview(imageView)
            return container

        case "content":
            let container = NSView()

            let appLabel = NSTextField(labelWithString: notification.appName)
            appLabel.font = NSFont.systemFont(ofSize: 11)
            appLabel.textColor = .secondaryLabelColor
            appLabel.frame = NSRect(x: 0, y: 32, width: 280, height: 14)
            container.addSubview(appLabel)

            let titleLabel = NSTextField(labelWithString: notification.title)
            titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.frame = NSRect(x: 0, y: 17, width: 280, height: 16)
            container.addSubview(titleLabel)

            let bodyText = notification.subtitle.isEmpty ? notification.body : "\(notification.subtitle) - \(notification.body)"
            let bodyLabel = NSTextField(labelWithString: bodyText)
            bodyLabel.font = NSFont.systemFont(ofSize: 11)
            bodyLabel.textColor = .secondaryLabelColor
            bodyLabel.lineBreakMode = .byTruncatingTail
            bodyLabel.frame = NSRect(x: 0, y: 2, width: 280, height: 14)
            container.addSubview(bodyLabel)

            return container

        case "time":
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let timeLabel = NSTextField(labelWithString: formatter.string(from: notification.timestamp))
            timeLabel.font = NSFont.systemFont(ofSize: 11)
            timeLabel.textColor = .secondaryLabelColor
            timeLabel.alignment = .right
            return timeLabel

        case "action":
            let button = NSButton(frame: NSRect(x: 0, y: 13, width: 24, height: 24))
            button.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Delete")
            button.isBordered = false
            button.target = self
            button.action = #selector(deleteNotification(_:))
            button.tag = row
            let container = NSView()
            container.addSubview(button)
            return container

        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 50
    }
}
