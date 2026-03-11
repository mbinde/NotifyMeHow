import Cocoa

/// UI helper functions for creating common controls
struct UIHelpers {
    /// Create a standard label for use in preference panes and editor windows
    /// Uses macOS standard 13pt system font
    static func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }
}
