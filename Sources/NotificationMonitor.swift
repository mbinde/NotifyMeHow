import ApplicationServices
import Cocoa

/// Mode for handling notification display
enum NotificationMode {
    case reposition       // Just move the original notification
    case replaceWithLarger // Hide original, show custom larger notification
}

/// Configuration for where to place notifications
struct NotificationPosition {
    enum Corner: String {
        case topLeft = "topLeft"
        case topCenter = "topCenter"
        case topRight = "topRight"
        case middleLeft = "middleLeft"
        case center = "center"
        case middleRight = "middleRight"
        case bottomLeft = "bottomLeft"
        case bottomCenter = "bottomCenter"
        case bottomRight = "bottomRight"
    }

    var corner: Corner
    var offsetX: CGFloat
    var offsetY: CGFloat

    static let topLeft = NotificationPosition(corner: .topLeft, offsetX: 20, offsetY: 40)
    static let topCenter = NotificationPosition(corner: .topCenter, offsetX: 0, offsetY: 40)
    static let topRight = NotificationPosition(corner: .topRight, offsetX: 20, offsetY: 40)
    static let middleLeft = NotificationPosition(corner: .middleLeft, offsetX: 20, offsetY: 0)
    static let center = NotificationPosition(corner: .center, offsetX: 0, offsetY: 0)
    static let middleRight = NotificationPosition(corner: .middleRight, offsetX: 20, offsetY: 0)
    static let bottomLeft = NotificationPosition(corner: .bottomLeft, offsetX: 20, offsetY: 20)
    static let bottomCenter = NotificationPosition(corner: .bottomCenter, offsetX: 0, offsetY: 20)
    static let bottomRight = NotificationPosition(corner: .bottomRight, offsetX: 20, offsetY: 20)

    static let defaultTopRight = topRight
}

/// Monitors for notification windows and repositions them
class NotificationMonitor {
    private var observer: AXObserver?
    private var isRunning = false
    private var targetPosition: NotificationPosition
    private var scaleFactor: CGFloat
    private var showCustomNotification: Bool = false
    private var customConfig: CustomNotificationConfig?

    // Track recently shown notifications to avoid duplicates
    private var recentNotifications: [(content: String, time: Date)] = []
    private let dedupeWindow: TimeInterval = 0.5

    init(position: NotificationPosition = .bottomRight, scaleFactor: CGFloat = 1.0) {
        self.targetPosition = position
        self.scaleFactor = scaleFactor
    }

    /// Enable custom notifications that duplicate the system notification
    func enableCustomNotifications(config: CustomNotificationConfig) {
        self.showCustomNotification = true
        self.customConfig = config
        CustomNotificationManager.shared.configure(config)
    }

    /// Disable custom notifications
    func disableCustomNotifications() {
        self.showCustomNotification = false
        self.customConfig = nil
    }

    func start() {
        guard checkAccessibilityPermissions() else {
            print("ERROR: Accessibility permissions not granted.")
            return
        }

        guard let pid = getNotificationCenterPID() else {
            print("ERROR: Could not find NotificationCenter process")
            return
        }

        print("Found NotificationCenter process with PID: \(pid)")

        // Create an observer for the NotificationCenter process
        var observerRef: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            guard let refcon = refcon else { return }
            let monitor = Unmanaged<NotificationMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handleNotification(element: element, notification: notification as String)
        }

        let result = AXObserverCreate(pid, callback, &observerRef)
        guard result == .success, let observer = observerRef else {
            print("ERROR: Could not create AXObserver: \(result)")
            return
        }

        self.observer = observer

        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        // Watch for window creation and content updates
        let notifications = [
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXUIElementDestroyedNotification,
            kAXMovedNotification,
            kAXResizedNotification,
            kAXValueChangedNotification,
            kAXLayoutChangedNotification
        ]

        for notif in notifications {
            let addResult = AXObserverAddNotification(observer, app, notif as CFString, refcon)
            if addResult != .success && addResult != .notificationAlreadyRegistered {
                print("Warning: Could not add notification \(notif): \(addResult)")
            }
        }

        // Add observer to run loop
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        isRunning = true
        print("Notification monitor started.")
        print("Target position: \(targetPosition.corner), offset: (\(targetPosition.offsetX), \(targetPosition.offsetY))")

        // Reposition any existing notifications
        repositionAllNotifications()
    }

    func stop() {
        if let observer = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        observer = nil
        isRunning = false
        print("Notification monitor stopped.")
    }

    func setPosition(_ position: NotificationPosition) {
        targetPosition = position
        repositionAllNotifications()
    }

    func setScaleFactor(_ factor: CGFloat) {
        scaleFactor = factor
        print("Scale factor updated to: \(factor)")
    }

    // MARK: - Notification Handling

    private func handleNotification(element: AXUIElement, notification: String) {
        if notification == kAXWindowCreatedNotification as String ||
           notification == kAXValueChangedNotification as String ||
           notification == kAXLayoutChangedNotification as String {
            processNotificationWindow(element)
        }
    }

    /// Process a notification window - reposition it and optionally show custom notification
    private func processNotificationWindow(_ window: AXUIElement) {
        // Find the banner within the window
        let targetSubroles = ["AXNotificationCenterBanner", "AXNotificationCenterAlert"]
        guard let banner = findElementWithSubrole(window, targetSubroles: targetSubroles) else {
            return
        }

        // Reposition the notification
        repositionBanner(banner)

        // Show custom notification if rules match
        showCustomNotificationIfNeeded(from: banner)
    }

    /// Reposition all currently visible notifications
    func repositionAllNotifications() {
        let banners = findNotificationBanners(verbose: false)
        for banner in banners {
            repositionBanner(banner)
        }
    }

    // MARK: - Positioning Logic (single code path)

    /// Reposition a notification banner to the target position
    private func repositionBanner(_ banner: AXUIElement) {
        guard let bannerPos = getPosition(of: banner),
              let bannerSize = getSize(of: banner) else {
            return
        }

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Calculate target position
        let targetPoint = calculateTargetPosition(forSize: bannerSize, in: screenFrame)

        // Check if already at target (avoid fighting with system)
        let tolerance: CGFloat = 5.0
        if abs(bannerPos.x - targetPoint.x) < tolerance && abs(bannerPos.y - targetPoint.y) < tolerance {
            return
        }

        // Get the parent window - that's what we actually move
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(banner, kAXWindowAttribute as CFString, &windowRef)
        guard windowResult == .success, let window = windowRef else {
            return
        }
        let windowElement = window as! AXUIElement

        guard let windowPos = getPosition(of: windowElement) else {
            return
        }

        // Calculate where window needs to be so banner lands at target
        let bannerOffsetInWindow = CGPoint(
            x: bannerPos.x - windowPos.x,
            y: bannerPos.y - windowPos.y
        )

        let newWindowPos = CGPoint(
            x: targetPoint.x - bannerOffsetInWindow.x,
            y: targetPoint.y - bannerOffsetInWindow.y
        )

        _ = NotifyMeHow.setPosition(of: windowElement, to: newWindowPos)
    }

    /// Calculate the target screen position for a notification of given size
    /// Note: Accessibility API uses screen coordinates where Y=0 is at TOP of screen
    private func calculateTargetPosition(forSize size: CGSize, in screenFrame: CGRect) -> CGPoint {
        var x: CGFloat
        var y: CGFloat
        let screenHeight = screenFrame.height

        // Horizontal position
        switch targetPosition.corner {
        case .topRight, .middleRight, .bottomRight:
            x = screenFrame.maxX - size.width - targetPosition.offsetX
        case .topLeft, .middleLeft, .bottomLeft:
            x = screenFrame.minX + targetPosition.offsetX
        case .topCenter, .center, .bottomCenter:
            x = screenFrame.midX - size.width / 2
        }

        // Vertical position (AX coordinates: Y=0 at top)
        switch targetPosition.corner {
        case .topLeft, .topCenter, .topRight:
            y = targetPosition.offsetY
        case .middleLeft, .center, .middleRight:
            y = screenHeight / 2 - size.height / 2
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = screenHeight - size.height - targetPosition.offsetY
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Custom Notifications

    private func showCustomNotificationIfNeeded(from banner: AXUIElement) {
        let content = CustomNotificationManager.shared.extractContent(from: banner)
        guard !content.title.isEmpty || !content.body.isEmpty else { return }

        // Deduplicate
        let contentHash = "\(content.appName)|\(content.title)|\(content.subtitle)|\(content.body)"
        let now = Date()

        recentNotifications.removeAll { now.timeIntervalSince($0.time) > dedupeWindow }

        let isDuplicate = recentNotifications.contains { $0.content == contentHash }
        guard !isDuplicate else { return }

        // Check rules and show if matched
        if let style = RulesManager.shared.styleFor(content: content) {
            let config = style.toConfig()
            CustomNotificationManager.shared.configure(config)
            CustomNotificationManager.shared.showNotification(content: content)
            recentNotifications.append((content: contentHash, time: now))
        }
    }

    // MARK: - Helpers

    private func findElementWithSubrole(_ root: AXUIElement, targetSubroles: [String]) -> AXUIElement? {
        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(root, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String, targetSubroles.contains(subrole) {
            return root
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let found = findElementWithSubrole(child, targetSubroles: targetSubroles) {
                return found
            }
        }
        return nil
    }
}
