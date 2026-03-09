import ApplicationServices
import Cocoa

/// Mode for handling notification display
enum NotificationMode {
    case reposition       // Just move the original notification
    case replaceWithLarger // Hide original, show custom larger notification
}

/// Configuration for where to place notifications
struct NotificationPosition {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight, center
    }

    var corner: Corner
    var offsetX: CGFloat
    var offsetY: CGFloat

    static let defaultTopRight = NotificationPosition(corner: .topRight, offsetX: 20, offsetY: 40)
    static let bottomRight = NotificationPosition(corner: .bottomRight, offsetX: 20, offsetY: 20)
    static let bottomLeft = NotificationPosition(corner: .bottomLeft, offsetX: 20, offsetY: 20)
    static let topLeft = NotificationPosition(corner: .topLeft, offsetX: 20, offsetY: 40)
    static let center = NotificationPosition(corner: .center, offsetX: 0, offsetY: 0)
}

/// Monitors for notification windows and repositions them
class NotificationMonitor {
    private var observer: AXObserver?
    private var isRunning = false
    private var targetPosition: NotificationPosition
    private var scaleFactor: CGFloat
    private var showCustomNotification: Bool = false
    private var customConfig: CustomNotificationConfig?
    private var seenBanners: Set<String> = []  // Track banners we've already processed

    // Cached initial notification data (like PingPlace)
    private var cachedInitialPosition: CGPoint?
    private var cachedInitialWindowSize: CGSize?
    private var cachedInitialNotifSize: CGSize?
    private var cachedInitialPadding: CGFloat?

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

    func start() {
        guard checkAccessibilityPermissions() else {
            print("ERROR: Accessibility permissions not granted.")
            print("Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility")
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

        // Watch for window creation and focus changes
        let notifications = [
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXUIElementDestroyedNotification,
            kAXMovedNotification,
            kAXResizedNotification
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
        print("Scale factor: \(scaleFactor)")

        // Also reposition any existing notification windows
        repositionExistingNotifications()
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
        print("Position updated to: \(position.corner)")
        repositionExistingNotifications()
    }

    func setScaleFactor(_ factor: CGFloat) {
        scaleFactor = factor
        print("Scale factor updated to: \(factor)")
    }

    private func handleNotification(element: AXUIElement, notification: String) {
        // For window creation, move the element directly like PingPlace does
        if notification == kAXWindowCreatedNotification as String {
            moveNotificationPingPlaceStyle(element)
        }
    }

    /// Move notification using PingPlace's approach - relative positioning on the window
    private func moveNotificationPingPlaceStyle(_ window: AXUIElement) {
        // Skip if topRight (default position)
        if case .topRight = targetPosition.corner { return }

        // Find the banner container within the window
        let targetSubroles = ["AXNotificationCenterBanner", "AXNotificationCenterAlert"]
        guard let windowSize = getSize(of: window),
              let bannerContainer = findElementWithSubrole(window, targetSubroles: targetSubroles),
              let notifSize = getSize(of: bannerContainer),
              let position = getPosition(of: bannerContainer) else {
            return
        }

        // Cache initial data if not already cached
        if cachedInitialPosition == nil {
            cacheInitialNotificationData(windowSize: windowSize, notifSize: notifSize, position: position)
        }

        guard let cachedPos = cachedInitialPosition,
              let cachedWinSize = cachedInitialWindowSize,
              let cachedNotifSize = cachedInitialNotifSize,
              let cachedPad = cachedInitialPadding else { return }

        // Calculate new position as RELATIVE offset (like PingPlace does)
        let newPosition = calculateNewPositionPingPlaceStyle(
            windowSize: cachedWinSize,
            notifSize: cachedNotifSize,
            position: cachedPos,
            padding: cachedPad
        )

        // Set position directly on the window
        var point = CGPoint(x: newPosition.x, y: newPosition.y)
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }

        // Show custom notification if enabled
        if showCustomNotification {
            let content = CustomNotificationManager.shared.extractContent(from: bannerContainer)
            if !content.title.isEmpty || !content.body.isEmpty {
                CustomNotificationManager.shared.showNotification(content: content)
            }
        }
    }

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

    private func cacheInitialNotificationData(windowSize: CGSize, notifSize: CGSize, position: CGPoint) {
        guard cachedInitialPosition == nil else { return }

        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.frame.width

        var padding: CGFloat
        var effectivePosition = position

        if position.x + notifSize.width > screenWidth {
            padding = 16.0
            effectivePosition.x = screenWidth - notifSize.width - padding
        } else {
            let rightEdge = position.x + notifSize.width
            padding = screenWidth - rightEdge
        }

        cachedInitialPosition = effectivePosition
        cachedInitialWindowSize = windowSize
        cachedInitialNotifSize = notifSize
        cachedInitialPadding = padding
    }

    private func calculateNewPositionPingPlaceStyle(
        windowSize: CGSize,
        notifSize: CGSize,
        position: CGPoint,
        padding: CGFloat
    ) -> (x: CGFloat, y: CGFloat) {
        var newX: CGFloat
        var newY: CGFloat

        guard let screen = NSScreen.main else { return (0, 0) }
        let dockSize = screen.frame.height - screen.visibleFrame.height
        let paddingAboveDock: CGFloat = 30

        // Horizontal positioning (relative offset)
        switch targetPosition.corner {
        case .topLeft, .bottomLeft:
            newX = padding - position.x
        case .center:
            newX = (windowSize.width - notifSize.width) / 2 - position.x
        case .topRight, .bottomRight:
            newX = 0
        }

        // Vertical positioning (relative offset)
        switch targetPosition.corner {
        case .topLeft, .topRight:
            newY = 0
        case .center:
            newY = (windowSize.height - notifSize.height) / 2 - dockSize
        case .bottomLeft, .bottomRight:
            newY = windowSize.height - notifSize.height - dockSize - paddingAboveDock
        }

        return (newX, newY)
    }

    func repositionExistingNotifications() {
        // Find actual notification banners (not just windows) using the correct subrole
        let banners = findNotificationBanners(verbose: false)
        if banners.isEmpty { return }

        for (index, banner) in banners.enumerated() {
            repositionBanner(banner, index: index)
        }
    }

    private func repositionBanner(_ banner: AXUIElement, index: Int) {
        guard let currentPos = getPosition(of: banner),
              let currentSize = getSize(of: banner) else {
            return
        }

        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let screenHeight = screenFrame.height

        // Calculate new position based on target corner
        var newX: CGFloat
        var newY: CGFloat

        switch targetPosition.corner {
        case .topRight:
            newX = screenFrame.maxX - currentSize.width - targetPosition.offsetX
            newY = targetPosition.offsetY
        case .topLeft:
            newX = targetPosition.offsetX
            newY = targetPosition.offsetY
        case .bottomRight:
            newX = screenFrame.maxX - currentSize.width - targetPosition.offsetX
            newY = screenHeight - currentSize.height - targetPosition.offsetY
        case .bottomLeft:
            newX = targetPosition.offsetX
            newY = screenHeight - currentSize.height - targetPosition.offsetY
        case .center:
            newX = screenFrame.midX - currentSize.width / 2
            newY = screenHeight / 2 - currentSize.height / 2
        }

        // Stack multiple notifications
        let stackOffset = CGFloat(index) * (currentSize.height + 10)
        switch targetPosition.corner {
        case .topLeft, .topRight:
            newY += stackOffset
        case .bottomLeft, .bottomRight:
            newY -= stackOffset
        case .center:
            newY += stackOffset
        }

        let newPosition = CGPoint(x: newX, y: newY)

        // Get the parent window - that's what we need to move
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(banner, kAXWindowAttribute as CFString, &windowRef)
        guard windowResult == .success, let window = windowRef else {
            return
        }

        let windowElement = window as! AXUIElement

        // Get window's current position and size
        guard let windowPos = getPosition(of: windowElement),
              let windowSize = getSize(of: windowElement) else {
            return
        }

        // If this is the huge container window, we still move it but need to
        // calculate based on where the banner is WITHIN the window
        if windowSize.width > 500 || windowSize.height > 300 {
            // The banner position within the window tells us where the notification actually is
            // We need to offset the window so the banner ends up at our target
            let bannerOffsetInWindow = CGPoint(
                x: currentPos.x - windowPos.x,
                y: currentPos.y - windowPos.y
            )

            // Check if banner is already at target (within tolerance)
            let tolerance: CGFloat = 5.0
            if abs(currentPos.x - newX) < tolerance && abs(currentPos.y - newY) < tolerance {
                return
            }

            // Calculate where the window needs to be so the banner lands at our target
            let adjustedWindowPos = CGPoint(
                x: newX - bannerOffsetInWindow.x,
                y: newY - bannerOffsetInWindow.y
            )

            _ = NotifyMeHow.setPosition(of: windowElement, to: adjustedWindowPos)
            return
        }

        // Only move if not already at target (avoid fighting with ourselves)
        let tolerance: CGFloat = 50
        if abs(windowPos.x - newX) < tolerance && abs(windowPos.y - newY) < tolerance {
            return
        }

        _ = NotifyMeHow.setPosition(of: windowElement, to: newPosition)
    }

    private func repositionWindow(_ window: AXUIElement, index: Int) {
        guard let currentPos = getPosition(of: window),
              let currentSize = getSize(of: window) else {
            print("Could not get window position/size")
            return
        }

        // Skip windows that are too large (likely the NC container, not a notification banner)
        // Typical notification banners are around 350-400px wide and 80-120px tall
        if currentSize.width > 500 || currentSize.height > 200 {
            print("Window \(index): Skipping (too large: \(currentSize.width)x\(currentSize.height) - likely container)")
            return
        }

        print("Window \(index): Current position (\(currentPos.x), \(currentPos.y)), size \(currentSize.width)x\(currentSize.height)")

        // Try using CGS private API instead of accessibility API for the actual move
        var usedCGS = false
        if let windowID = getWindowID(from: window) {
            print("  Window ID: \(windowID), trying CGS API...")
            usedCGS = true
        }

        // Get screen dimensions
        // Note: Accessibility API uses screen coordinates where Y=0 is at TOP-LEFT
        // NSScreen uses Cocoa coordinates where Y=0 is at BOTTOM-LEFT
        // We need to convert: AX_Y = screenHeight - Cocoa_Y - windowHeight
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let screenHeight = screenFrame.height

        print("  Screen: \(screenFrame.width)x\(screenFrame.height), origin: (\(screenFrame.origin.x), \(screenFrame.origin.y))")

        // Calculate new position based on target corner
        // All Y values here are in Accessibility coordinates (0 at top)
        var newX: CGFloat
        var newY: CGFloat

        // DEBUG: Try setting to absolute screen coordinates
        // The notification is visually at top-right but AX reports x=20
        // Let's try moving it to an obviously different spot
        switch targetPosition.corner {
        case .topRight:
            newX = screenFrame.maxX - currentSize.width - targetPosition.offsetX
            newY = targetPosition.offsetY
        case .topLeft:
            newX = targetPosition.offsetX  // Left edge + offset
            newY = targetPosition.offsetY
        case .bottomRight:
            newX = screenFrame.maxX - currentSize.width - targetPosition.offsetX
            newY = screenHeight - currentSize.height - targetPosition.offsetY
        case .bottomLeft:
            // Try absolute coordinates: left side of screen, near bottom
            newX = 100  // Obviously left side
            newY = 700  // Lower on screen (AX coords: 0=top)
        case .center:
            newX = screenFrame.midX - currentSize.width / 2 + targetPosition.offsetX
            newY = screenHeight / 2 - currentSize.height / 2 + targetPosition.offsetY
        }

        print("  Attempting to move from (\(currentPos.x), \(currentPos.y)) to (\(newX), \(newY))")

        // Stack multiple notifications vertically
        let stackOffset = CGFloat(index) * (currentSize.height + 10)
        switch targetPosition.corner {
        case .topLeft, .topRight:
            newY += stackOffset
        case .bottomLeft, .bottomRight:
            newY -= stackOffset
        case .center:
            newY += stackOffset
        }

        let newPosition = CGPoint(x: newX, y: newY)
        print("  Target position: (\(newX), \(newY))")

        // Try CGS API first (more likely to work for system windows)
        var moved = false
        if let windowID = getWindowID(from: window) {
            if moveWindowCGS(windowID: windowID, to: newPosition) {
                print("  [CGS] Successfully moved window")
                moved = true
            } else {
                print("  [CGS] Failed to move window")
            }
        }

        // Fall back to accessibility API
        if !moved {
            if NotifyMeHow.setPosition(of: window, to: newPosition) {
                print("  [AX] Successfully moved notification window")
            } else {
                print("  [AX] Failed to move notification window")
            }
        }

        // Try to scale the notification if requested
        if scaleFactor != 1.0 {
            tryScaleWindow(window, scaleFactor: scaleFactor)
        }
    }

    /// Try multiple approaches to scale a window
    private func tryScaleWindow(_ window: AXUIElement, scaleFactor: CGFloat) {
        print("Attempting to scale window by factor: \(scaleFactor)")

        // Approach 1: Try accessibility API size change (usually fails for system windows)
        if let currentSize = getSize(of: window) {
            let newSize = CGSize(width: currentSize.width * scaleFactor, height: currentSize.height * scaleFactor)
            if NotifyMeHow.setSize(of: window, to: newSize) {
                print("  [AX API] Successfully resized notification window")
                return
            } else {
                print("  [AX API] Could not resize via accessibility API")
            }
        }

        // Approach 2: Try CGS private API transform
        if let windowID = getWindowID(from: window) {
            print("  [CGS API] Found window ID: \(windowID)")

            // Try applying a scale transform
            if applyScaleTransform(to: windowID, scale: scaleFactor, centerOnOriginal: true) {
                print("  [CGS API] Successfully applied scale transform")
                return
            } else {
                print("  [CGS API] Failed to apply scale transform")

                // Note: CGS has a restriction that you can't scale UP past the original frame
                // But we can try scaling DOWN if scale < 1.0
                if scaleFactor > 1.0 {
                    print("  [CGS API] Note: CGS restricts scaling UP past original window size")
                    print("  [CGS API] Scaling DOWN (factor < 1.0) may work")
                }
            }
        } else {
            print("  [CGS API] Could not get window ID from accessibility element")
        }

        print("  All scaling approaches failed - notification windows may not support resizing")
    }
}
