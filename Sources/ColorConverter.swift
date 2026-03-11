import Cocoa

/// Utility for converting between NSColor and hex strings
struct ColorConverter {
    /// Convert a hex string (e.g., "FF0000" or "#FF0000") to NSColor
    static func colorFromHex(_ hex: String, alpha: CGFloat = 0.9) -> NSColor {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleanHex.count == 6 else {
            return NSColor.black.withAlphaComponent(0.85)
        }

        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: alpha)
    }

    /// Convert an NSColor to a hex string (e.g., "FF0000")
    static func hexFromColor(_ color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return "000000"
        }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
