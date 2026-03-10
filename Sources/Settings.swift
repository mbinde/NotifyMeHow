import Cocoa
import ServiceManagement

/// Keys for UserDefaults storage
private enum SettingsKey: String {
    case positionCorner = "positionCorner"
    case positionOffsetX = "positionOffsetX"
    case positionOffsetY = "positionOffsetY"
    case scaleFactor = "scaleFactor"
    case enableCustomNotification = "enableCustomNotification"
    case customPositionCorner = "customPositionCorner"
    case customPositionOffsetX = "customPositionOffsetX"
    case customPositionOffsetY = "customPositionOffsetY"
    case customScale = "customScale"
    case customOpacity = "customOpacity"
    case customDwellTime = "customDwellTime"
    case customColorHex = "customColorHex"
    case customAppColorHex = "customAppColorHex"
    case customTitleColorHex = "customTitleColorHex"
    case customBodyColorHex = "customBodyColorHex"
    case autoStartMonitoring = "autoStartMonitoring"
    case launchAtLogin = "launchAtLogin"
}

/// Manages persistent settings using UserDefaults
class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    // Notification posted when settings change
    static let didChangeNotification = Notification.Name("SettingsDidChange")

    private init() {}

    // MARK: - Position Settings

    var positionCorner: NotificationPosition.Corner {
        get {
            guard let raw = defaults.string(forKey: SettingsKey.positionCorner.rawValue),
                  let corner = NotificationPosition.Corner(rawValue: raw) else {
                return .topRight  // Default
            }
            return corner
        }
        set {
            defaults.set(newValue.rawValue, forKey: SettingsKey.positionCorner.rawValue)
            notifyChange()
        }
    }

    var positionOffsetX: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.positionOffsetX.rawValue) == nil {
                return 20  // Default
            }
            return CGFloat(defaults.double(forKey: SettingsKey.positionOffsetX.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.positionOffsetX.rawValue)
            notifyChange()
        }
    }

    var positionOffsetY: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.positionOffsetY.rawValue) == nil {
                return 40  // Default for top positions
            }
            return CGFloat(defaults.double(forKey: SettingsKey.positionOffsetY.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.positionOffsetY.rawValue)
            notifyChange()
        }
    }

    var position: NotificationPosition {
        get {
            return NotificationPosition(corner: positionCorner, offsetX: positionOffsetX, offsetY: positionOffsetY)
        }
        set {
            positionCorner = newValue.corner
            positionOffsetX = newValue.offsetX
            positionOffsetY = newValue.offsetY
        }
    }

    var scaleFactor: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.scaleFactor.rawValue) == nil {
                return 1.0  // Default
            }
            return CGFloat(defaults.double(forKey: SettingsKey.scaleFactor.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.scaleFactor.rawValue)
            notifyChange()
        }
    }

    // MARK: - Custom Notification Settings

    var enableCustomNotification: Bool {
        get { defaults.bool(forKey: SettingsKey.enableCustomNotification.rawValue) }
        set {
            defaults.set(newValue, forKey: SettingsKey.enableCustomNotification.rawValue)
            notifyChange()
        }
    }

    var customPositionCorner: NotificationPosition.Corner {
        get {
            guard let raw = defaults.string(forKey: SettingsKey.customPositionCorner.rawValue),
                  let corner = NotificationPosition.Corner(rawValue: raw) else {
                return .bottomLeft  // Default
            }
            return corner
        }
        set {
            defaults.set(newValue.rawValue, forKey: SettingsKey.customPositionCorner.rawValue)
            notifyChange()
        }
    }

    var customPositionOffsetX: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.customPositionOffsetX.rawValue) == nil {
                return 20
            }
            return CGFloat(defaults.double(forKey: SettingsKey.customPositionOffsetX.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.customPositionOffsetX.rawValue)
            notifyChange()
        }
    }

    var customPositionOffsetY: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.customPositionOffsetY.rawValue) == nil {
                return 20
            }
            return CGFloat(defaults.double(forKey: SettingsKey.customPositionOffsetY.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.customPositionOffsetY.rawValue)
            notifyChange()
        }
    }

    var customPosition: NotificationPosition {
        get {
            return NotificationPosition(corner: customPositionCorner, offsetX: customPositionOffsetX, offsetY: customPositionOffsetY)
        }
        set {
            customPositionCorner = newValue.corner
            customPositionOffsetX = newValue.offsetX
            customPositionOffsetY = newValue.offsetY
        }
    }

    var customScale: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.customScale.rawValue) == nil {
                return 1.5  // Default
            }
            return CGFloat(defaults.double(forKey: SettingsKey.customScale.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.customScale.rawValue)
            notifyChange()
        }
    }

    var customOpacity: CGFloat {
        get {
            if defaults.object(forKey: SettingsKey.customOpacity.rawValue) == nil {
                return 0.95  // Default
            }
            return CGFloat(defaults.double(forKey: SettingsKey.customOpacity.rawValue))
        }
        set {
            defaults.set(Double(newValue), forKey: SettingsKey.customOpacity.rawValue)
            notifyChange()
        }
    }

    var customDwellTime: TimeInterval {
        get {
            if defaults.object(forKey: SettingsKey.customDwellTime.rawValue) == nil {
                return 5.0  // Default
            }
            return defaults.double(forKey: SettingsKey.customDwellTime.rawValue)
        }
        set {
            defaults.set(newValue, forKey: SettingsKey.customDwellTime.rawValue)
            notifyChange()
        }
    }

    var customColorHex: String {
        get {
            return defaults.string(forKey: SettingsKey.customColorHex.rawValue) ?? "000000"
        }
        set {
            defaults.set(newValue, forKey: SettingsKey.customColorHex.rawValue)
            notifyChange()
        }
    }

    var customColor: NSColor {
        get {
            return colorFromHex(customColorHex)
        }
        set {
            customColorHex = hexFromColor(newValue)
        }
    }

    var customAppColorHex: String {
        get {
            return defaults.string(forKey: SettingsKey.customAppColorHex.rawValue) ?? "AAAAAA"
        }
        set {
            defaults.set(newValue, forKey: SettingsKey.customAppColorHex.rawValue)
            notifyChange()
        }
    }

    var customAppColor: NSColor {
        get { return colorFromHex(customAppColorHex) }
        set { customAppColorHex = hexFromColor(newValue) }
    }

    var customTitleColorHex: String {
        get {
            return defaults.string(forKey: SettingsKey.customTitleColorHex.rawValue) ?? "FFFFFF"
        }
        set {
            defaults.set(newValue, forKey: SettingsKey.customTitleColorHex.rawValue)
            notifyChange()
        }
    }

    var customTitleColor: NSColor {
        get { return colorFromHex(customTitleColorHex) }
        set { customTitleColorHex = hexFromColor(newValue) }
    }

    var customBodyColorHex: String {
        get {
            return defaults.string(forKey: SettingsKey.customBodyColorHex.rawValue) ?? "DDDDDD"
        }
        set {
            defaults.set(newValue, forKey: SettingsKey.customBodyColorHex.rawValue)
            notifyChange()
        }
    }

    var customBodyColor: NSColor {
        get { return colorFromHex(customBodyColorHex) }
        set { customBodyColorHex = hexFromColor(newValue) }
    }

    // MARK: - App Settings

    var autoStartMonitoring: Bool {
        get {
            if defaults.object(forKey: SettingsKey.autoStartMonitoring.rawValue) == nil {
                return true  // Default to auto-start
            }
            return defaults.bool(forKey: SettingsKey.autoStartMonitoring.rawValue)
        }
        set {
            defaults.set(newValue, forKey: SettingsKey.autoStartMonitoring.rawValue)
            notifyChange()
        }
    }

    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return defaults.bool(forKey: SettingsKey.launchAtLogin.rawValue)
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
                }
            }
            defaults.set(newValue, forKey: SettingsKey.launchAtLogin.rawValue)
            notifyChange()
        }
    }

    // MARK: - Helper Methods

    private func notifyChange() {
        NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil)
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

    private func hexFromColor(_ color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return "000000"
        }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    // MARK: - Export/Import

    /// Container for full export including settings, styles, and rules
    struct ExportData: Codable {
        var version: Int = 1
        var settings: SettingsExport
        var styles: [NotificationStyle]
        var rules: [NotificationRule]
        var defaultBehavior: String
    }

    struct SettingsExport: Codable {
        var positionCorner: String
        var positionOffsetX: Double
        var positionOffsetY: Double
        var scaleFactor: Double
        var autoStartMonitoring: Bool
        var launchAtLogin: Bool
    }

    /// Export all settings, styles, and rules to JSON data
    func exportToJSON() -> Data? {
        let settingsExport = SettingsExport(
            positionCorner: positionCorner.rawValue,
            positionOffsetX: Double(positionOffsetX),
            positionOffsetY: Double(positionOffsetY),
            scaleFactor: Double(scaleFactor),
            autoStartMonitoring: autoStartMonitoring,
            launchAtLogin: launchAtLogin
        )

        let exportData = ExportData(
            version: 1,
            settings: settingsExport,
            styles: StylesManager.shared.styles,
            rules: RulesManager.shared.rules,
            defaultBehavior: RulesManager.shared.defaultBehavior == .noCustom ? "noCustom" : "showCustom"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(exportData)
    }

    /// Import all settings, styles, and rules from JSON data
    func importFromJSON(_ data: Data) -> Bool {
        let decoder = JSONDecoder()

        // Try new format first
        if let exportData = try? decoder.decode(ExportData.self, from: data) {
            // Import settings
            if let corner = NotificationPosition.Corner(rawValue: exportData.settings.positionCorner) {
                positionCorner = corner
            }
            positionOffsetX = CGFloat(exportData.settings.positionOffsetX)
            positionOffsetY = CGFloat(exportData.settings.positionOffsetY)
            scaleFactor = CGFloat(exportData.settings.scaleFactor)
            autoStartMonitoring = exportData.settings.autoStartMonitoring
            launchAtLogin = exportData.settings.launchAtLogin

            // Import styles (replace all)
            StylesManager.shared.replaceAllStyles(exportData.styles)

            // Import rules (replace all)
            RulesManager.shared.replaceAllRules(exportData.rules)
            RulesManager.shared.defaultBehavior = exportData.defaultBehavior == "noCustom" ? .noCustom : .showCustom

            return true
        }

        // Fall back to old format for backwards compatibility
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let corner = dict["positionCorner"] as? String,
           let c = NotificationPosition.Corner(rawValue: corner) {
            positionCorner = c
        }
        if let x = dict["positionOffsetX"] as? Double { positionOffsetX = CGFloat(x) }
        if let y = dict["positionOffsetY"] as? Double { positionOffsetY = CGFloat(y) }
        if let s = dict["scaleFactor"] as? Double { scaleFactor = CGFloat(s) }
        if let a = dict["autoStartMonitoring"] as? Bool { autoStartMonitoring = a }
        if let l = dict["launchAtLogin"] as? Bool { launchAtLogin = l }

        return true
    }

    /// Build a CustomNotificationConfig from current settings
    func buildCustomConfig() -> CustomNotificationConfig {
        var config = CustomNotificationConfig()
        config.position = customPosition
        config.scaleFactor = customScale
        config.opacity = customOpacity
        config.dwellTime = customDwellTime
        config.backgroundColor = customColor
        config.appColor = customAppColor
        config.titleColor = customTitleColor
        config.bodyColor = customBodyColor
        return config
    }
}
