import Cocoa
import ApplicationServices

/// Configuration for custom notification appearance
struct CustomNotificationConfig {
    var backgroundColor: NSColor = NSColor.black.withAlphaComponent(0.85)
    var titleColor: NSColor = .white
    var subtitleColor: NSColor = NSColor.white.withAlphaComponent(0.8)
    var bodyColor: NSColor = NSColor.white.withAlphaComponent(0.7)
    var titleFontSize: CGFloat = 16
    var subtitleFontSize: CGFloat = 13
    var bodyFontSize: CGFloat = 13
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16
    var width: CGFloat = 380
    var maxHeight: CGFloat = 200
    var opacity: CGFloat = 1.0
    var dwellTime: TimeInterval = 5.0  // How long to show before auto-dismiss
    var position: NotificationPosition = .bottomLeft
    var scaleFactor: CGFloat = 1.5  // Make it bigger than original
}

/// Content extracted from a notification
struct NotificationContent {
    var appName: String = ""
    var title: String = ""
    var subtitle: String = ""
    var body: String = ""
}

/// Manages custom notification windows
class CustomNotificationManager {
    static let shared = CustomNotificationManager()

    private var activeWindows: [NSWindow] = []
    private var config = CustomNotificationConfig()

    func configure(_ config: CustomNotificationConfig) {
        self.config = config
    }

    /// Extract content from an AX notification banner
    func extractContent(from banner: AXUIElement) -> NotificationContent {
        var content = NotificationContent()

        // Get app name from description
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(banner, kAXDescriptionAttribute as CFString, &descRef) == .success,
           let desc = descRef as? String {
            // Format: "AppName, Title, Subtitle, Body"
            let parts = desc.components(separatedBy: ", ")
            if parts.count > 0 {
                content.appName = parts[0]
            }
        }

        // Get text values from children
        var texts: [String] = []
        extractTexts(from: banner, into: &texts)

        if texts.count >= 1 { content.title = texts[0] }
        if texts.count >= 2 { content.subtitle = texts[1] }
        if texts.count >= 3 { content.body = texts[2] }

        return content
    }

    private func extractTexts(from element: AXUIElement, into texts: inout [String]) {
        // Check for AXValue (text content)
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
           let value = valueRef as? String, !value.isEmpty {
            texts.append(value)
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                extractTexts(from: child, into: &texts)
            }
        }
    }

    /// Show a custom notification window
    func showNotification(content: NotificationContent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let window = self.createNotificationWindow(content: content)
            self.activeWindows.append(window)

            // Position the window
            self.positionWindow(window)

            // Show with fade-in
            window.alphaValue = 0
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = self.config.opacity
            }

            // Auto-dismiss after dwell time
            DispatchQueue.main.asyncAfter(deadline: .now() + self.config.dwellTime) { [weak self] in
                self?.dismissNotification(window)
            }
        }
    }

    private func dismissNotification(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.activeWindows.removeAll { $0 == window }
        })
    }

    private func createNotificationWindow(content: NotificationContent) -> NSWindow {
        let scaledWidth = config.width * config.scaleFactor
        let scaledPadding = config.padding * config.scaleFactor
        let scaledCornerRadius = config.cornerRadius * config.scaleFactor

        // Create content view
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = config.backgroundColor.cgColor
        contentView.layer?.cornerRadius = scaledCornerRadius

        var yOffset = scaledPadding
        let textWidth = scaledWidth - (scaledPadding * 2)

        // App name (small, at top)
        if !content.appName.isEmpty {
            let appLabel = createLabel(
                text: content.appName.uppercased(),
                fontSize: config.subtitleFontSize * config.scaleFactor * 0.8,
                color: config.subtitleColor.withAlphaComponent(0.6),
                width: textWidth
            )
            appLabel.frame.origin = CGPoint(x: scaledPadding, y: 0)  // Will adjust later
            contentView.addSubview(appLabel)
            yOffset += appLabel.frame.height + 4
        }

        // Title
        if !content.title.isEmpty {
            let titleLabel = createLabel(
                text: content.title,
                fontSize: config.titleFontSize * config.scaleFactor,
                color: config.titleColor,
                width: textWidth,
                bold: true
            )
            titleLabel.frame.origin = CGPoint(x: scaledPadding, y: 0)
            contentView.addSubview(titleLabel)
            yOffset += titleLabel.frame.height + 4
        }

        // Subtitle
        if !content.subtitle.isEmpty {
            let subtitleLabel = createLabel(
                text: content.subtitle,
                fontSize: config.subtitleFontSize * config.scaleFactor,
                color: config.subtitleColor,
                width: textWidth
            )
            subtitleLabel.frame.origin = CGPoint(x: scaledPadding, y: 0)
            contentView.addSubview(subtitleLabel)
            yOffset += subtitleLabel.frame.height + 4
        }

        // Body
        if !content.body.isEmpty {
            let bodyLabel = createLabel(
                text: content.body,
                fontSize: config.bodyFontSize * config.scaleFactor,
                color: config.bodyColor,
                width: textWidth
            )
            bodyLabel.frame.origin = CGPoint(x: scaledPadding, y: 0)
            contentView.addSubview(bodyLabel)
            yOffset += bodyLabel.frame.height
        }

        yOffset += scaledPadding

        // Now position all subviews from top to bottom
        var currentY = yOffset - scaledPadding
        for subview in contentView.subviews.reversed() {
            currentY -= subview.frame.height
            subview.frame.origin.y = currentY
            currentY -= 4
        }

        let windowHeight = min(yOffset, config.maxHeight * config.scaleFactor)

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: scaledWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = contentView
        contentView.frame = window.contentView!.bounds

        return window
    }

    private func createLabel(text: String, fontSize: CGFloat, color: NSColor, width: CGFloat, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = width
        label.sizeToFit()

        // Ensure width doesn't exceed max
        if label.frame.width > width {
            label.frame.size.width = width
        }

        return label
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        var x: CGFloat
        var y: CGFloat

        switch config.position.corner {
        case .topRight:
            x = screenFrame.maxX - windowFrame.width - config.position.offsetX
            y = screenFrame.maxY - windowFrame.height - config.position.offsetY
        case .topLeft:
            x = screenFrame.minX + config.position.offsetX
            y = screenFrame.maxY - windowFrame.height - config.position.offsetY
        case .bottomRight:
            x = screenFrame.maxX - windowFrame.width - config.position.offsetX
            y = screenFrame.minY + config.position.offsetY
        case .bottomLeft:
            x = screenFrame.minX + config.position.offsetX
            y = screenFrame.minY + config.position.offsetY
        case .center:
            x = screenFrame.midX - windowFrame.width / 2
            y = screenFrame.midY - windowFrame.height / 2
        }

        // Stack multiple notifications
        let stackOffset = CGFloat(activeWindows.count - 1) * (windowFrame.height + 10)
        switch config.position.corner {
        case .topLeft, .topRight:
            y -= stackOffset
        case .bottomLeft, .bottomRight:
            y += stackOffset
        case .center:
            y -= stackOffset
        }

        window.setFrameOrigin(CGPoint(x: x, y: y))
    }
}
