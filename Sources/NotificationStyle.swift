import Cocoa

/// A reusable notification style
struct NotificationStyle: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "New Style"
    var position: String = "bottomLeft"         // Corner rawValue
    var offsetX: Double = 20
    var offsetY: Double = 20
    var scale: Double = 1.5
    var opacity: Double = 0.95
    var dwellTime: Double = 5.0
    var backgroundColorHex: String = "1A1A1A"
    var appColorHex: String = "AAAAAA"
    var titleColorHex: String = "FFFFFF"
    var subtitleColorHex: String = "DDDDDD"
    var bodyColorHex: String = "DDDDDD"
    var customIconPath: String? = nil           // Path to custom icon image
    var backgroundImagePath: String? = nil      // Path to background image
    var showAppName: Bool = false                // Whether to show app name label
    var borderWidth: Double = 0                  // Border width (0 = none)
    var borderColorHex: String = "FFFFFF"        // Border color
    var animation: String = "none"               // Animation type: none, pulse, jiggle, wiggle, bounce
    var animationLoops: Bool = false             // Whether animation repeats continuously
    var hideSystemNotification: Bool = false     // Move system notification off-screen when showing custom

    /// Convert to CustomNotificationConfig
    func toConfig() -> CustomNotificationConfig {
        var config = CustomNotificationConfig()

        if let corner = NotificationPosition.Corner(rawValue: position) {
            config.position = NotificationPosition(corner: corner, offsetX: CGFloat(offsetX), offsetY: CGFloat(offsetY))
        }
        config.scaleFactor = CGFloat(scale)
        config.opacity = CGFloat(opacity)
        config.dwellTime = dwellTime
        config.backgroundColor = colorFromHex(backgroundColorHex)
        config.appColor = colorFromHex(appColorHex)
        config.titleColor = colorFromHex(titleColorHex)
        config.subtitleColor = colorFromHex(subtitleColorHex)
        config.bodyColor = colorFromHex(bodyColorHex)

        // Load custom icon if path is set
        if let iconPath = customIconPath, !iconPath.isEmpty {
            config.customIcon = NSImage(contentsOfFile: iconPath)
        }

        // Load background image if path is set
        if let bgImagePath = backgroundImagePath, !bgImagePath.isEmpty {
            config.backgroundImage = NSImage(contentsOfFile: bgImagePath)
        }

        config.showAppName = showAppName
        config.borderWidth = CGFloat(borderWidth)
        config.borderColor = colorFromHex(borderColorHex)
        config.animation = animation
        config.animationLoops = animationLoops
        config.hideSystemNotification = hideSystemNotification

        return config
    }

    private func colorFromHex(_ hex: String) -> NSColor {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleanHex.count == 6 else {
            return NSColor.black.withAlphaComponent(0.85)
        }

        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 0.9)
    }

    /// Create a default style
    static var defaultStyle: NotificationStyle {
        return NotificationStyle(name: "Default")
    }
}

/// Manages saved notification styles
class StylesManager {
    static let shared = StylesManager()

    private let stylesKey = "notificationStyles"
    private(set) var styles: [NotificationStyle] = []

    // Notification for when styles change
    static let didChangeNotification = Notification.Name("StylesDidChange")

    private init() {
        loadStyles()
        // Ensure there's always at least a default style
        if styles.isEmpty {
            let defaultStyle = NotificationStyle(name: "Default")
            styles.append(defaultStyle)
            saveStyles()
        }
    }

    func style(withId id: UUID) -> NotificationStyle? {
        return styles.first { $0.id == id }
    }

    func style(named name: String) -> NotificationStyle? {
        return styles.first { $0.name == name }
    }

    // MARK: - CRUD Operations

    func addStyle(_ style: NotificationStyle) {
        styles.append(style)
        saveStyles()
        notifyChange()
    }

    func updateStyle(_ style: NotificationStyle) {
        if let index = styles.firstIndex(where: { $0.id == style.id }) {
            styles[index] = style
            saveStyles()
            notifyChange()
        }
    }

    func deleteStyle(at index: Int) {
        guard index >= 0 && index < styles.count else { return }
        // Don't allow deleting the last style
        if styles.count <= 1 { return }
        styles.remove(at: index)
        saveStyles()
        notifyChange()
    }

    func deleteStyle(withId id: UUID) {
        if styles.count <= 1 { return }
        styles.removeAll { $0.id == id }
        saveStyles()
        notifyChange()
    }

    /// Replace all styles with imported styles (for import functionality)
    func replaceAllStyles(_ newStyles: [NotificationStyle]) {
        // Ensure at least one style
        if newStyles.isEmpty {
            styles = [NotificationStyle(name: "Default")]
        } else {
            styles = newStyles
        }
        saveStyles()
        notifyChange()
    }

    // MARK: - Persistence

    private func loadStyles() {
        guard let data = UserDefaults.standard.data(forKey: stylesKey) else {
            styles = []
            return
        }

        do {
            styles = try JSONDecoder().decode([NotificationStyle].self, from: data)
        } catch {
            print("Failed to decode styles: \(error)")
            styles = []
        }
    }

    private func saveStyles() {
        do {
            let data = try JSONEncoder().encode(styles)
            UserDefaults.standard.set(data, forKey: stylesKey)
        } catch {
            print("Failed to encode styles: \(error)")
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: StylesManager.didChangeNotification, object: nil)
    }
}
