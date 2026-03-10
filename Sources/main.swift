import Cocoa
import ApplicationServices

// Check if running in GUI mode (default) vs CLI mode
func shouldRunGUI() -> Bool {
    let args = CommandLine.arguments
    // CLI mode only if specific CLI flags are passed
    let cliFlags = ["--help", "-h", "--position", "-p", "--scale", "-s",
                    "--debug", "-d", "--test-hide", "--offset-x", "-ox",
                    "--offset-y", "-oy", "--custom", "-c"]
    for arg in args {
        if cliFlags.contains(arg) {
            return false
        }
    }
    // Default to GUI mode
    return true
}

struct ParsedArgs {
    var position: NotificationPosition = .bottomRight
    var scale: CGFloat = 1.0
    var debug: Bool = false
    var enableCustom: Bool = false
    var customPosition: NotificationPosition = .bottomLeft
    var customScale: CGFloat = 1.5
    var customOpacity: CGFloat = 0.95
    var customDwell: TimeInterval = 5.0
    var customBgColor: NSColor = NSColor.black.withAlphaComponent(0.85)
}

// Parse command line arguments
func parseArguments() -> ParsedArgs {
    var args = ParsedArgs()
    let argv = CommandLine.arguments

    var i = 0
    while i < argv.count {
        switch argv[i] {
        case "--position", "-p":
            if i + 1 < argv.count {
                args.position = parsePosition(argv[i + 1])
                i += 1
            }

        case "--offset-x", "-ox":
            if i + 1 < argv.count, let val = Double(argv[i + 1]) {
                args.position.offsetX = CGFloat(val)
                i += 1
            }

        case "--offset-y", "-oy":
            if i + 1 < argv.count, let val = Double(argv[i + 1]) {
                args.position.offsetY = CGFloat(val)
                i += 1
            }

        case "--scale", "-s":
            if i + 1 < argv.count, let val = Double(argv[i + 1]) {
                args.scale = CGFloat(val)
                i += 1
            }

        case "--debug", "-d":
            args.debug = true

        case "--custom", "-c":
            args.enableCustom = true

        case "--custom-position", "-cp":
            if i + 1 < argv.count {
                args.customPosition = parsePosition(argv[i + 1])
                i += 1
            }

        case "--custom-scale", "-cs":
            if i + 1 < argv.count, let val = Double(argv[i + 1]) {
                args.customScale = CGFloat(val)
                i += 1
            }

        case "--custom-opacity", "-co":
            if i + 1 < argv.count, let val = Double(argv[i + 1]) {
                args.customOpacity = CGFloat(val)
                i += 1
            }

        case "--custom-dwell", "-cd":
            if i + 1 < argv.count, let val = Double(argv[i + 1]) {
                args.customDwell = val
                i += 1
            }

        case "--custom-color", "-cc":
            if i + 1 < argv.count {
                args.customBgColor = parseColor(argv[i + 1])
                i += 1
            }

        case "--test-hide":
            testHideNotifications()
            exit(0)

        case "--help", "-h":
            printHelp()
            exit(0)

        default:
            break
        }
        i += 1
    }

    return args
}

func parsePosition(_ str: String) -> NotificationPosition {
    switch str.lowercased() {
    case "top-left", "tl":
        return NotificationPosition(corner: .topLeft, offsetX: 20, offsetY: 40)
    case "top-center", "tc":
        return NotificationPosition(corner: .topCenter, offsetX: 0, offsetY: 40)
    case "top-right", "tr":
        return NotificationPosition(corner: .topRight, offsetX: 20, offsetY: 40)
    case "middle-left", "ml":
        return NotificationPosition(corner: .middleLeft, offsetX: 20, offsetY: 0)
    case "center", "c":
        return NotificationPosition(corner: .center, offsetX: 0, offsetY: 0)
    case "middle-right", "mr":
        return NotificationPosition(corner: .middleRight, offsetX: 20, offsetY: 0)
    case "bottom-left", "bl":
        return NotificationPosition(corner: .bottomLeft, offsetX: 20, offsetY: 20)
    case "bottom-center", "bc":
        return NotificationPosition(corner: .bottomCenter, offsetX: 0, offsetY: 20)
    case "bottom-right", "br":
        return NotificationPosition(corner: .bottomRight, offsetX: 20, offsetY: 20)
    default:
        print("Unknown position: \(str), using bottom-right")
        return .bottomRight
    }
}

func parseColor(_ str: String) -> NSColor {
    // Named colors first (check before hex since "purple" is 6 chars)
    switch str.lowercased() {
    case "black": return NSColor.black.withAlphaComponent(0.85)
    case "white": return NSColor.white.withAlphaComponent(0.9)
    case "blue": return NSColor.systemBlue.withAlphaComponent(0.9)
    case "red": return NSColor.systemRed.withAlphaComponent(0.9)
    case "green": return NSColor.systemGreen.withAlphaComponent(0.9)
    case "purple": return NSColor.systemPurple.withAlphaComponent(0.9)
    case "orange": return NSColor.systemOrange.withAlphaComponent(0.9)
    default:
        // Try hex color like "#FF0000" or "FF0000"
        let hex = str.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) {
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            let b = CGFloat(rgb & 0xFF) / 255.0
            return NSColor(red: r, green: g, blue: b, alpha: 0.9)
        }
        print("Unknown color: \(str), using black")
        return NSColor.black.withAlphaComponent(0.85)
    }
}

func printHelp() {
    print("""
    NotifyMeHow - Customize macOS notification position

    Usage: NotifyMeHow [options]

    Options:
      -p, --position <pos>    Set notification position (for original notification)
                              Values: top-right (tr), top-left (tl),
                                      bottom-right (br), bottom-left (bl),
                                      center (c)
                              Default: bottom-right

      -ox, --offset-x <val>   Horizontal offset from edge in pixels
      -oy, --offset-y <val>   Vertical offset from edge in pixels

    Custom Notification Options (shows a duplicate with full customization):
      -c, --custom            Enable custom duplicate notification

      -cp, --custom-position  Position for custom notification
                              Default: bottom-left

      -cs, --custom-scale     Scale factor for custom notification
                              Default: 1.5 (50% larger than original)

      -co, --custom-opacity   Opacity of custom notification (0.0-1.0)
                              Default: 0.95

      -cd, --custom-dwell     How long custom notification stays (seconds)
                              Default: 5.0

      -cc, --custom-color     Background color (hex like FF0000 or name)
                              Names: black, white, blue, red, green, purple, orange
                              Default: black

    Other Options:
      -d, --debug             Print debug information about windows
      -g, --gui               Run as menu bar application (GUI mode)
      --test-hide             Test hiding notification windows (experimental)
      -h, --help              Show this help message

    Examples:
      NotifyMeHow -p bottom-left
      NotifyMeHow -p center -ox 0 -oy 100

      # Show custom large notification in bottom-left, original in center-right:
      NotifyMeHow -p center -c -cp bottom-left -cs 2.0 -co 0.9 -cd 8

      # Purple custom notification:
      NotifyMeHow -c -cc purple -cs 1.8

    Note: This application requires Accessibility permissions.
          Grant access in System Settings > Privacy & Security > Accessibility
    """)
}

func runDebugMode() {
    print("=== NotifyMeHow Debug Mode ===\n")

    // Check accessibility
    print("Checking accessibility permissions...")
    if checkAccessibilityPermissions() {
        print("✓ Accessibility permissions granted\n")
    } else {
        print("✗ Accessibility permissions NOT granted")
        print("  Please grant access in System Settings > Privacy & Security > Accessibility\n")
        return
    }

    // Find NotificationCenter
    print("Looking for NotificationCenter process...")
    if let pid = getNotificationCenterPID() {
        print("✓ Found NotificationCenter with PID: \(pid)\n")
    } else {
        print("✗ NotificationCenter process not found\n")
        return
    }

    // Get windows
    print("Enumerating NotificationCenter windows...")
    let windows = getNotificationWindows()
    print("Found \(windows.count) window(s)\n")

    for (i, window) in windows.enumerated() {
        print("--- Window \(i) ---")
        print("Full hierarchy:")
        printElementHierarchy(window, indent: "  ", maxDepth: 4)
        print()
    }

    // Also search for specific banner subroles
    print("\n=== Searching for Banner Subroles ===")
    let banners = findNotificationBanners()
    print("Total banner elements found: \(banners.count)\n")

    for (i, banner) in banners.enumerated() {
        print("--- Banner \(i) ---")
        debugElement(banner, indent: "  ")
        if let windowID = getWindowID(from: banner) {
            print("  CGWindowID: \(windowID)")
        }
        print()
    }

    if windows.isEmpty {
        print("No notification windows currently visible.")
        print("Try sending a test notification:")
        print("  osascript -e 'display notification \"Test\" with title \"Hello\"'")
    } else {
        // Also try to get CGS window info
        print("\n=== CGS Window Information ===")
        guard let pid = getNotificationCenterPID() else { return }

        let cgsWindows = listWindowsForProcess(pid: pid)
        print("Found \(cgsWindows.count) window(s) via CGWindowList\n")

        for (windowID, info) in cgsWindows {
            print("Window ID: \(windowID)")
            if let name = info[kCGWindowName as String] as? String {
                print("  Name: \(name)")
            }
            if let layer = info[kCGWindowLayer as String] as? Int {
                print("  Layer: \(layer)")
            }
            if let bounds = info["kCGWindowBounds"] as? [String: Any] {
                print("  Bounds: \(bounds)")
            }
            print()
        }

        // Try getting window ID from AX element
        print("=== Attempting AX -> CGS Window ID mapping ===")
        for (i, window) in windows.enumerated() {
            if let windowID = getWindowID(from: window) {
                print("Window \(i): AX element maps to CGWindowID \(windowID)")

                // Try to get/set transform
                var transform = CGAffineTransform.identity
                let cid = CGSDefaultConnection()
                let result = CGSGetWindowTransform(cid, windowID, &transform)
                if result == .success {
                    print("  Current transform: a=\(transform.a), b=\(transform.b), c=\(transform.c), d=\(transform.d), tx=\(transform.tx), ty=\(transform.ty)")
                } else {
                    print("  Could not get transform (error: \(result.rawValue))")
                }
            } else {
                print("Window \(i): Could not get CGWindowID from AX element")
            }
        }
    }
}

/// Test hiding notification windows using CGSSetWindowAlpha
func testHideNotifications() {
    print("=== Testing Notification Window Hiding ===\n")

    guard checkAccessibilityPermissions() else {
        print("ERROR: Accessibility permissions required")
        return
    }

    guard let pid = getNotificationCenterPID() else {
        print("ERROR: NotificationCenter process not found")
        return
    }

    let windows = getNotificationWindows()
    if windows.isEmpty {
        print("No notification windows found.")
        print("Send a test notification first:")
        print("  osascript -e 'display notification \"Test\" with title \"Hello\"'")
        return
    }

    print("Found \(windows.count) notification window(s)")

    for (i, window) in windows.enumerated() {
        guard let windowID = getWindowID(from: window) else {
            print("Window \(i): Could not get CGWindowID")
            continue
        }

        print("\nWindow \(i) (ID: \(windowID)):")

        // Get current alpha
        if let alpha = getWindowAlpha(windowID: windowID) {
            print("  Current alpha: \(alpha)")
        }

        // Try to hide it
        print("  Attempting to hide window...")
        if hideWindow(windowID: windowID) {
            print("  SUCCESS: Window hidden!")
            print("  Waiting 2 seconds then restoring...")

            Thread.sleep(forTimeInterval: 2.0)

            if showWindow(windowID: windowID) {
                print("  Window restored")
            } else {
                print("  Failed to restore window")
            }
        } else {
            print("  FAILED: Could not hide window")
            print("  This may be due to window ownership restrictions")
        }
    }

    print("\nTest complete.")
}

// Main execution
if shouldRunGUI() {
    runMenuBarApp()
    exit(0)
}

print("NotifyMeHow - macOS Notification Position Customizer")
print("====================================================\n")

let parsedArgs = parseArguments()

if parsedArgs.debug {
    runDebugMode()
    exit(0)
}

// Check permissions first
if !checkAccessibilityPermissions() {
    print("ERROR: Accessibility permissions required.")
    print("A system dialog should appear prompting you to grant access.")
    print("If not, go to System Settings > Privacy & Security > Accessibility")
    print("and add this application to the list.")
    exit(1)
}

// Create and start the monitor
let monitor = NotificationMonitor(position: parsedArgs.position, scaleFactor: parsedArgs.scale)

// Enable custom notifications if requested
if parsedArgs.enableCustom {
    var customConfig = CustomNotificationConfig()
    customConfig.position = parsedArgs.customPosition
    customConfig.scaleFactor = parsedArgs.customScale
    customConfig.opacity = parsedArgs.customOpacity
    customConfig.dwellTime = parsedArgs.customDwell
    customConfig.backgroundColor = parsedArgs.customBgColor
    monitor.enableCustomNotifications(config: customConfig)
    print("Custom notifications enabled:")
    print("  Position: \(parsedArgs.customPosition.corner)")
    print("  Scale: \(parsedArgs.customScale)x")
    print("  Opacity: \(parsedArgs.customOpacity)")
    print("  Dwell time: \(parsedArgs.customDwell)s")
    print("  Color: \(customConfig.backgroundColor)")
}

monitor.start()

print("\nPress Ctrl+C to stop\n")

// Set up signal handler for clean exit
signal(SIGINT) { _ in
    print("\nShutting down...")
    exit(0)
}

// Run the main loop
RunLoop.main.run()
