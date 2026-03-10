import ApplicationServices
import Cocoa

/// Check if accessibility permissions are granted (prompts user via system dialog if not)
func checkAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

/// Check if accessibility permissions are granted without prompting
func hasAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

/// Get the PID of the NotificationCenter process
func getNotificationCenterPID() -> pid_t? {
    let runningApps = NSWorkspace.shared.runningApplications
    for app in runningApps {
        if app.bundleIdentifier == "com.apple.notificationcenterui" ||
           app.localizedName == "NotificationCenter" {
            return app.processIdentifier
        }
    }
    return nil
}

/// Get all windows from the NotificationCenter process
func getNotificationWindows() -> [AXUIElement] {
    guard let pid = getNotificationCenterPID() else {
        return []
    }

    let app = AXUIElementCreateApplication(pid)
    var windowsRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)

    guard result == .success, let windows = windowsRef as? [AXUIElement] else {
        return []
    }

    return windows
}

/// Get the position of an AXUIElement
func getPosition(of element: AXUIElement) -> CGPoint? {
    var positionRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)

    guard result == .success else { return nil }

    var point = CGPoint.zero
    if AXValueGetValue(positionRef as! AXValue, .cgPoint, &point) {
        return point
    }
    return nil
}

/// Get the size of an AXUIElement
func getSize(of element: AXUIElement) -> CGSize? {
    var sizeRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

    guard result == .success else { return nil }

    var size = CGSize.zero
    if AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
        return size
    }
    return nil
}

/// Set the position of an AXUIElement
func setPosition(of element: AXUIElement, to point: CGPoint) -> Bool {
    var mutablePoint = point
    guard let positionValue = AXValueCreate(.cgPoint, &mutablePoint) else {
        return false
    }

    let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
    return result == .success
}

/// Set the size of an AXUIElement (experimental - may not work for notifications)
func setSize(of element: AXUIElement, to size: CGSize) -> Bool {
    var mutableSize = size
    guard let sizeValue = AXValueCreate(.cgSize, &mutableSize) else {
        return false
    }

    let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
    return result == .success
}

/// Get the role of an AXUIElement
func getRole(of element: AXUIElement) -> String? {
    var roleRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)

    guard result == .success, let role = roleRef as? String else {
        return nil
    }
    return role
}

/// Get the subrole of an AXUIElement
func getSubrole(of element: AXUIElement) -> String? {
    var subroleRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)

    guard result == .success, let subrole = subroleRef as? String else {
        return nil
    }
    return subrole
}

/// Get all attribute names of an AXUIElement (for debugging)
func getAttributeNames(of element: AXUIElement) -> [String]? {
    var namesRef: CFArray?
    let result = AXUIElementCopyAttributeNames(element, &namesRef)

    guard result == .success, let names = namesRef as? [String] else {
        return nil
    }
    return names
}

/// Print debug info about an element
func debugElement(_ element: AXUIElement, indent: String = "") {
    let role = getRole(of: element) ?? "unknown"
    let subrole = getSubrole(of: element) ?? "none"
    let position = getPosition(of: element)
    let size = getSize(of: element)

    print("\(indent)Role: \(role), Subrole: \(subrole)")
    if let pos = position {
        print("\(indent)  Position: (\(pos.x), \(pos.y))")
    }
    if let sz = size {
        print("\(indent)  Size: \(sz.width) x \(sz.height)")
    }
}

/// Get the children of an AXUIElement
func getChildren(of element: AXUIElement) -> [AXUIElement]? {
    var childrenRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

    guard result == .success, let children = childrenRef as? [AXUIElement] else {
        return nil
    }
    return children
}

/// Recursively print the element hierarchy
func printElementHierarchy(_ element: AXUIElement, indent: String = "", maxDepth: Int = 3) {
    guard maxDepth > 0 else {
        print("\(indent)  ...")
        return
    }

    debugElement(element, indent: indent)

    if let children = getChildren(of: element) {
        for (i, child) in children.enumerated() {
            print("\(indent)  Child \(i):")
            printElementHierarchy(child, indent: indent + "    ", maxDepth: maxDepth - 1)
        }
    }
}

/// Get the title/description of an element
func getTitle(of element: AXUIElement) -> String? {
    var titleRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    if result == .success, let title = titleRef as? String {
        return title
    }

    // Try description as fallback
    var descRef: CFTypeRef?
    let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
    if descResult == .success, let desc = descRef as? String {
        return desc
    }

    return nil
}

/// Find elements with a specific subrole within a hierarchy
func findElementsWithSubrole(_ element: AXUIElement, subrole targetSubrole: String, maxDepth: Int = 5) -> [AXUIElement] {
    var results: [AXUIElement] = []

    if let subrole = getSubrole(of: element), subrole == targetSubrole {
        results.append(element)
    }

    if maxDepth > 0, let children = getChildren(of: element) {
        for child in children {
            results.append(contentsOf: findElementsWithSubrole(child, subrole: targetSubrole, maxDepth: maxDepth - 1))
        }
    }

    return results
}

/// Find the actual notification banner elements (not just windows)
func findNotificationBanners(verbose: Bool = true) -> [AXUIElement] {
    guard let pid = getNotificationCenterPID() else {
        return []
    }

    let app = AXUIElementCreateApplication(pid)

    // Look for elements with these specific subroles that PingPlace uses
    let bannerSubroles = [
        "AXNotificationCenterBanner",
        "AXNotificationCenterBannerWindow",
        "AXNotificationCenterAlert",
        "AXNotificationCenterNotification"
    ]

    var allBanners: [AXUIElement] = []

    for subrole in bannerSubroles {
        let found = findElementsWithSubrole(app, subrole: subrole, maxDepth: 6)
        if !found.isEmpty {
            if verbose {
                print("Found \(found.count) element(s) with subrole: \(subrole)")
            }
            allBanners.append(contentsOf: found)
        }
    }

    return allBanners
}
