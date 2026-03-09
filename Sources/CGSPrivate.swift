import Foundation
import ApplicationServices

// MARK: - Private CoreGraphics Services (CGS) API declarations
// These are undocumented/private APIs for advanced window manipulation

/// CGS Connection ID type
typealias CGSConnectionID = Int32

/// Get the default CGS connection for this process
@_silgen_name("_CGSDefaultConnection")
func CGSDefaultConnection() -> CGSConnectionID

/// Alternative modern name for the default connection
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

/// Move a window to a new position
/// - Parameters:
///   - cid: Connection ID
///   - wid: Window ID
///   - origin: New origin point (top-left)
@_silgen_name("CGSMoveWindow")
func CGSMoveWindow(_ cid: CGSConnectionID, _ wid: CGWindowID, _ origin: UnsafePointer<CGPoint>) -> CGError

/// Set an affine transform on a window
/// - Note: Has restrictions - cannot scale UP past the window's original frame size
/// - Parameters:
///   - cid: Connection ID
///   - wid: Window ID
///   - transform: The affine transform to apply
@_silgen_name("CGSSetWindowTransform")
func CGSSetWindowTransform(_ cid: CGSConnectionID, _ wid: CGWindowID, _ transform: CGAffineTransform) -> CGError

/// Get the current transform of a window
@_silgen_name("CGSGetWindowTransform")
func CGSGetWindowTransform(_ cid: CGSConnectionID, _ wid: CGWindowID, _ outTransform: UnsafeMutablePointer<CGAffineTransform>) -> CGError

/// Set the alpha (opacity) of a window
@_silgen_name("CGSSetWindowAlpha")
func CGSSetWindowAlpha(_ cid: CGSConnectionID, _ wid: CGWindowID, _ alpha: Float) -> CGError

/// Get the alpha of a window
@_silgen_name("CGSGetWindowAlpha")
func CGSGetWindowAlpha(_ cid: CGSConnectionID, _ wid: CGWindowID, _ outAlpha: UnsafeMutablePointer<Float>) -> CGError

/// Set the window level (z-order)
@_silgen_name("CGSSetWindowLevel")
func CGSSetWindowLevel(_ cid: CGSConnectionID, _ wid: CGWindowID, _ level: Int32) -> CGError

/// Private function to get AXUIElement's window ID
/// This connects accessibility elements to CGS window IDs
@_silgen_name("_AXUIElementGetWindow")
func AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - Helper functions

/// Get the CGWindowID from an AXUIElement
func getWindowID(from element: AXUIElement) -> CGWindowID? {
    var windowID: CGWindowID = 0
    let result = AXUIElementGetWindow(element, &windowID)
    if result == .success {
        return windowID
    }
    return nil
}

/// Apply a scale transform to a window using private CGS API
/// - Note: Scaling UP may not work due to CGS restrictions
/// - Parameters:
///   - windowID: The CGWindowID to transform
///   - scale: Scale factor (1.0 = normal, 0.5 = half size, 2.0 = double - may not work)
///   - centerOnOriginal: If true, adjusts translation to keep window centered
/// - Returns: true if successful
func applyScaleTransform(to windowID: CGWindowID, scale: CGFloat, centerOnOriginal: Bool = true) -> Bool {
    let cid = CGSDefaultConnection()

    // Get current transform
    var currentTransform = CGAffineTransform.identity
    let getResult = CGSGetWindowTransform(cid, windowID, &currentTransform)
    if getResult != .success {
        print("Failed to get current window transform: \(getResult)")
    }

    // Create scale transform
    var transform = CGAffineTransform(scaleX: scale, y: scale)

    // If we want to center on the original position, we need to add translation
    // to compensate for the scaling origin being at (0,0)
    if centerOnOriginal {
        // Get window bounds to calculate offset
        if let windowInfo = getWindowInfo(windowID: windowID),
           let bounds = windowInfo["kCGWindowBounds"] as? [String: CGFloat] {
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0

            // Calculate the translation needed to keep the center in place
            let offsetX = width * (1 - scale) / 2
            let offsetY = height * (1 - scale) / 2

            transform = transform.translatedBy(x: offsetX / scale, y: offsetY / scale)
        }
    }

    let result = CGSSetWindowTransform(cid, windowID, transform)
    if result == .success {
        print("Successfully applied scale transform (\(scale)) to window \(windowID)")
        return true
    } else {
        print("Failed to apply scale transform: \(result.rawValue)")
        return false
    }
}

/// Reset a window's transform to identity (no transform)
func resetWindowTransform(windowID: CGWindowID) -> Bool {
    let cid = CGSDefaultConnection()
    let result = CGSSetWindowTransform(cid, windowID, .identity)
    return result == .success
}

/// Move a window using private CGS API (potentially faster/more reliable than accessibility)
func moveWindowCGS(windowID: CGWindowID, to point: CGPoint) -> Bool {
    let cid = CGSDefaultConnection()
    var origin = point
    let result = CGSMoveWindow(cid, windowID, &origin)
    return result == .success
}

/// Get window information from CGWindowListCopyWindowInfo
func getWindowInfo(windowID: CGWindowID) -> [String: Any]? {
    guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]] else {
        return nil
    }
    return windowList.first
}

/// List all windows from a specific process
func listWindowsForProcess(pid: pid_t) -> [(windowID: CGWindowID, info: [String: Any])] {
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return []
    }

    return windowList.compactMap { info -> (CGWindowID, [String: Any])? in
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
              ownerPID == pid,
              let windowID = info[kCGWindowNumber as String] as? CGWindowID else {
            return nil
        }
        return (windowID, info)
    }
}

/// Hide a window by setting its alpha to 0
/// - Returns: true if successful
func hideWindow(windowID: CGWindowID) -> Bool {
    let cid = CGSDefaultConnection()
    let result = CGSSetWindowAlpha(cid, windowID, 0.0)
    if result == .success {
        print("Successfully hid window \(windowID)")
        return true
    } else {
        print("Failed to hide window \(windowID): error \(result.rawValue)")
        return false
    }
}

/// Show a window by setting its alpha to 1
func showWindow(windowID: CGWindowID) -> Bool {
    let cid = CGSDefaultConnection()
    let result = CGSSetWindowAlpha(cid, windowID, 1.0)
    return result == .success
}

/// Get current alpha of a window
func getWindowAlpha(windowID: CGWindowID) -> Float? {
    let cid = CGSDefaultConnection()
    var alpha: Float = 0
    let result = CGSGetWindowAlpha(cid, windowID, &alpha)
    if result == .success {
        return alpha
    }
    return nil
}
