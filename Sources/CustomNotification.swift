import Cocoa
import ApplicationServices

/// Configuration for custom notification appearance
struct CustomNotificationConfig {
    var backgroundColor: NSColor = NSColor.black.withAlphaComponent(0.85)
    var appColor: NSColor = NSColor.white.withAlphaComponent(0.6)
    var titleColor: NSColor = .white
    var subtitleColor: NSColor = NSColor.white.withAlphaComponent(0.8)
    var bodyColor: NSColor = NSColor.white.withAlphaComponent(0.7)
    var titleFontSize: CGFloat = 16
    var subtitleFontSize: CGFloat = 13
    var bodyFontSize: CGFloat = 13
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 10
    var width: CGFloat = 380
    var maxHeight: CGFloat = 200
    var opacity: CGFloat = 1.0
    var dwellTime: TimeInterval = 5.0  // How long to show before auto-dismiss
    var position: NotificationPosition = .bottomLeft
    var scaleFactor: CGFloat = 1.5  // Make it bigger than original
    var customIcon: NSImage? = nil  // Custom icon to override app icon
    var backgroundImage: NSImage? = nil  // Background image instead of solid color
    var maxBodyCharacters: Int = 500  // Max characters for body text (0 = unlimited)
    var maxBodyLines: Int = 4  // Max lines for body text (0 = unlimited)
    var showAppName: Bool = true  // Whether to show app name label
    var borderWidth: CGFloat = 0  // Border width (0 = none)
    var borderColor: NSColor = .white  // Border color
    var animation: String = "none"  // Animation type: none, pulse, jiggle, wiggle, bounce
    var animationLoops: Bool = false  // Whether animation repeats continuously
}

/// Content extracted from a notification
struct NotificationContent {
    var appName: String = ""
    var title: String = ""
    var subtitle: String = ""
    var body: String = ""
    var appIcon: NSImage? = nil      // App icon from bundle
    var profileImage: NSImage? = nil  // Profile/contact image if available
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

        // Get app icon from running applications
        if !content.appName.isEmpty {
            content.appIcon = getAppIcon(for: content.appName)
        }

        // Try to extract profile/contact image from AX hierarchy
        content.profileImage = extractImage(from: banner)

        return content
    }

    /// Get the app icon for a given app name
    private func getAppIcon(for appName: String) -> NSImage? {
        // Try to find the app in running applications
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let name = app.localizedName, name.localizedCaseInsensitiveContains(appName) {
                return app.icon
            }
        }

        // Try to find by bundle identifier patterns
        let workspace = NSWorkspace.shared
        let commonBundlePatterns = [
            "com.apple.\(appName.lowercased())",
            "com.apple.\(appName.lowercased().replacingOccurrences(of: " ", with: ""))"
        ]

        for pattern in commonBundlePatterns {
            if let url = workspace.urlForApplication(withBundleIdentifier: pattern) {
                return workspace.icon(forFile: url.path)
            }
        }

        return nil
    }

    /// Try to extract an image from the AX element hierarchy
    private func extractImage(from element: AXUIElement) -> NSImage? {
        // Check if this element has an image
        var imageRef: CFTypeRef?

        // Try AXImage attribute (some elements expose images this way)
        if AXUIElementCopyAttributeValue(element, "AXImage" as CFString, &imageRef) == .success {
            // AXImage can be various types - try to convert to NSImage
            if let cgImage = imageRef as! CGImage? {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        // Check role - look for image elements
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            if role == "AXImage" || role == kAXImageRole as String {
                // This is an image element - try to get its contents
                // Unfortunately, AX doesn't typically expose raw image data
                // but we can try a few approaches

                // Try AXValue which sometimes contains image data
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success {
                    if let cgImage = valueRef as! CGImage? {
                        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    }
                }
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let image = extractImage(from: child) {
                    return image
                }
            }
        }

        return nil
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
            } completionHandler: { [weak self] in
                // Start animation after fade-in completes
                self?.startAnimation(for: window)
            }

            // Auto-dismiss after dwell time (0 = indefinite, no auto-dismiss)
            if self.config.dwellTime > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.config.dwellTime) { [weak self] in
                    self?.dismissNotification(window)
                }
            }
        }
    }

    private func startAnimation(for window: NSWindow) {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }

        let repeatCount: Float = config.animationLoops ? .infinity : 1

        switch config.animation {
        case "pulse":
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = config.opacity
            pulse.toValue = config.opacity * 0.6
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = repeatCount
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(pulse, forKey: "pulse")

        case "jiggle":
            let jiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = Double.pi / 90  // ~2 degrees
            jiggle.values = [-angle, angle, -angle]
            jiggle.duration = 0.2
            jiggle.repeatCount = repeatCount
            jiggle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(jiggle, forKey: "jiggle")

        case "wiggle":
            // Decaying wiggle that settles down
            let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = Double.pi / 60  // ~3 degrees
            wiggle.values = [0, -angle, angle, -angle * 0.6, angle * 0.6, -angle * 0.3, angle * 0.3, 0]
            wiggle.keyTimes = [0, 0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0]
            wiggle.duration = 0.6
            wiggle.repeatCount = repeatCount
            layer.add(wiggle, forKey: "wiggle")

        case "bounce":
            let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
            bounce.values = [1.0, 1.05, 0.98, 1.02, 1.0]
            bounce.keyTimes = [0, 0.2, 0.5, 0.75, 1.0]
            bounce.duration = 0.5
            bounce.repeatCount = repeatCount
            bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(bounce, forKey: "bounce")

        default:
            break  // "none" - no animation
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

        // Determine icon size and layout
        let iconSize: CGFloat = 48 * config.scaleFactor
        let iconSpacing: CGFloat = 12 * config.scaleFactor
        let hasIcon = content.profileImage != nil || content.appIcon != nil

        // Text width accounts for icon if present
        let textWidth = hasIcon
            ? scaledWidth - (scaledPadding * 2) - iconSize - iconSpacing
            : scaledWidth - (scaledPadding * 2)

        // Collect all labels first to calculate total height
        var labels: [NSTextField] = []

        // App name (small, at top)
        if config.showAppName && !content.appName.isEmpty {
            let appLabel = createLabel(
                text: content.appName.uppercased(),
                fontSize: config.subtitleFontSize * config.scaleFactor * 0.8,
                color: config.appColor,
                width: textWidth
            )
            labels.append(appLabel)
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
            labels.append(titleLabel)
        }

        // Combine subtitle and body into one text block for consistent limiting
        var combinedText = ""
        if !content.subtitle.isEmpty {
            combinedText = content.subtitle
        }
        if !content.body.isEmpty {
            if !combinedText.isEmpty {
                combinedText += "\n"
            }
            combinedText += content.body
        }

        if !combinedText.isEmpty {
            // Truncate to max characters
            if config.maxBodyCharacters > 0 && combinedText.count > config.maxBodyCharacters {
                combinedText = String(combinedText.prefix(config.maxBodyCharacters - 1)) + "…"
            }

            let bodyLabel = createLabel(
                text: combinedText,
                fontSize: config.bodyFontSize * config.scaleFactor,
                color: config.bodyColor,
                width: textWidth,
                maxLines: config.maxBodyLines,
                addEllipsisIfTruncated: true
            )

            labels.append(bodyLabel)
        }

        // Calculate total height
        let spacing: CGFloat = 2
        var totalHeight = scaledPadding * 2
        for label in labels {
            totalHeight += label.frame.height + spacing
        }
        totalHeight -= spacing  // Remove last spacing

        // Ensure window is at least tall enough for the icon
        let minHeightForIcon = hasIcon ? iconSize + (scaledPadding * 2) : 0
        let windowHeight = min(max(totalHeight, minHeightForIcon), config.maxHeight * config.scaleFactor)

        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: scaledWidth, height: windowHeight))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = scaledCornerRadius
        contentView.layer?.masksToBounds = true

        // Add border if configured
        if config.borderWidth > 0 {
            contentView.layer?.borderWidth = config.borderWidth * config.scaleFactor
            contentView.layer?.borderColor = config.borderColor.cgColor
        }

        // Add background - either image or solid color
        if let bgImage = config.backgroundImage {
            // Use background image with aspect fill (scale to fill, crop excess)
            let imageSize = bgImage.size
            let viewSize = contentView.bounds.size
            let imageAspect = imageSize.width / imageSize.height
            let viewAspect = viewSize.width / viewSize.height

            var drawRect = contentView.bounds
            if imageAspect > viewAspect {
                // Image is wider than view - scale by height, crop width
                let scaledWidth = viewSize.height * imageAspect
                drawRect = NSRect(
                    x: (viewSize.width - scaledWidth) / 2,
                    y: 0,
                    width: scaledWidth,
                    height: viewSize.height
                )
            } else {
                // Image is taller than view - scale by width, crop height
                let scaledHeight = viewSize.width / imageAspect
                drawRect = NSRect(
                    x: 0,
                    y: (viewSize.height - scaledHeight) / 2,
                    width: viewSize.width,
                    height: scaledHeight
                )
            }

            let bgImageView = NSImageView(frame: drawRect)
            bgImageView.image = bgImage
            bgImageView.imageScaling = .scaleAxesIndependently  // Fill the calculated frame
            contentView.addSubview(bgImageView)

            // Add a semi-transparent overlay for text readability
            let overlay = NSView(frame: contentView.bounds)
            overlay.wantsLayer = true
            overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
            overlay.autoresizingMask = [.width, .height]
            contentView.addSubview(overlay)
        } else {
            // Solid color background
            contentView.layer?.backgroundColor = config.backgroundColor.cgColor
        }

        // Add icon if available (prefer: custom icon > profile image > app icon)
        let displayIcon = config.customIcon ?? content.profileImage ?? content.appIcon
        var iconView: NSImageView? = nil
        if hasIcon, let icon = displayIcon {
            // Calculate aspect-fill frame for non-square icons
            let iconFrame = NSRect(
                x: scaledPadding,
                y: (windowHeight - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            let imageSize = icon.size
            let imageAspect = imageSize.width / imageSize.height

            var imageFrame = iconFrame
            if imageAspect > 1 {
                // Image is wider - scale by height, crop width
                let scaledWidth = iconSize * imageAspect
                imageFrame = NSRect(
                    x: iconFrame.origin.x + (iconSize - scaledWidth) / 2,
                    y: iconFrame.origin.y,
                    width: scaledWidth,
                    height: iconSize
                )
            } else if imageAspect < 1 {
                // Image is taller - scale by width, crop height
                let scaledHeight = iconSize / imageAspect
                imageFrame = NSRect(
                    x: iconFrame.origin.x,
                    y: iconFrame.origin.y + (iconSize - scaledHeight) / 2,
                    width: iconSize,
                    height: scaledHeight
                )
            }

            // Container view for clipping
            let iconContainer = NSView(frame: iconFrame)
            iconContainer.wantsLayer = true
            iconContainer.layer?.cornerRadius = iconSize / 2  // Circular
            iconContainer.layer?.masksToBounds = true

            iconView = NSImageView(frame: NSRect(
                x: imageFrame.origin.x - iconFrame.origin.x,
                y: imageFrame.origin.y - iconFrame.origin.y,
                width: imageFrame.width,
                height: imageFrame.height
            ))
            iconView?.image = icon
            iconView?.imageScaling = .scaleAxesIndependently
            iconContainer.addSubview(iconView!)
            contentView.addSubview(iconContainer)
        }

        // Position labels from top to bottom (Cocoa coords: y=0 is bottom)
        let textX = hasIcon ? scaledPadding + iconSize + iconSpacing : scaledPadding
        var currentY = windowHeight - scaledPadding
        for label in labels {
            currentY -= label.frame.height
            label.frame.origin = CGPoint(x: textX, y: currentY)
            contentView.addSubview(label)
            currentY -= spacing
        }

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

    private func createLabel(text: String, fontSize: CGFloat, color: NSColor, width: CGFloat, bold: Bool = false, maxLines: Int = 0, addEllipsisIfTruncated: Bool = false) -> NSTextField {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)

        // Create label - wrapping label gives us word wrap
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.preferredMaxLayoutWidth = width
        label.maximumNumberOfLines = maxLines
        // Keep word wrapping, but truncate the last visible line
        label.lineBreakMode = .byWordWrapping
        label.cell?.truncatesLastVisibleLine = true

        // Calculate height using intrinsicContentSize
        label.frame.size.width = width
        label.layoutSubtreeIfNeeded()
        let height = label.intrinsicContentSize.height
        label.frame = NSRect(x: 0, y: 0, width: width, height: height)

        return label
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        var x: CGFloat
        var y: CGFloat

        // Horizontal position
        switch config.position.corner {
        case .topRight, .middleRight, .bottomRight:
            x = screenFrame.maxX - windowFrame.width - config.position.offsetX
        case .topLeft, .middleLeft, .bottomLeft:
            x = screenFrame.minX + config.position.offsetX
        case .topCenter, .center, .bottomCenter:
            x = screenFrame.midX - windowFrame.width / 2
        }

        // Vertical position
        switch config.position.corner {
        case .topLeft, .topCenter, .topRight:
            y = screenFrame.maxY - windowFrame.height - config.position.offsetY
        case .middleLeft, .center, .middleRight:
            y = screenFrame.midY - windowFrame.height / 2
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = screenFrame.minY + config.position.offsetY
        }

        // Stack multiple notifications
        let stackOffset = CGFloat(activeWindows.count - 1) * (windowFrame.height + 10)
        switch config.position.corner {
        case .topLeft, .topCenter, .topRight:
            y -= stackOffset
        case .bottomLeft, .bottomCenter, .bottomRight:
            y += stackOffset
        case .middleLeft, .center, .middleRight:
            y -= stackOffset
        }

        // Clamp to screen bounds to prevent off-screen notifications
        // (e.g., when importing settings from a different screen size)
        x = max(screenFrame.minX, min(x, screenFrame.maxX - windowFrame.width))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - windowFrame.height))

        window.setFrameOrigin(CGPoint(x: x, y: y))
    }
}
