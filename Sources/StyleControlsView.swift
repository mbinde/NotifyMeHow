import Cocoa

/// A reusable view containing all style editing controls (position, colors, icon, etc.)
class StyleControlsView: NSView {

    // MARK: - Public Properties

    /// The parent window for modal panels (icon/background pickers)
    weak var parentWindow: NSWindow?

    /// Get or set the current style values from/to the controls
    var style: NotificationStyle {
        get { buildStyleFromControls() }
        set { loadStyleIntoControls(newValue) }
    }

    // MARK: - Private UI Controls

    private var positionPopup: NSPopUpButton!
    private var offsetXField: NSTextField!
    private var offsetYField: NSTextField!
    private var scaleSlider: NSSlider!
    private var scaleLabel: NSTextField!
    private var opacitySlider: NSSlider!
    private var opacityLabel: NSTextField!
    private var dwellField: NSTextField!
    private var bgColorWell: NSColorWell!
    private var appColorWell: NSColorWell!
    private var titleColorWell: NSColorWell!
    private var subtitleColorWell: NSColorWell!
    private var bodyColorWell: NSColorWell!
    private var iconImageView: NSImageView!
    private var bgImageView: NSImageView!
    private var showAppNameCheckbox: NSButton!
    private var borderWidthSlider: NSSlider!
    private var borderWidthLabel: NSTextField!
    private var borderColorWell: NSColorWell!
    private var animationPopup: NSPopUpButton!

    // State
    private var customIconPath: String?
    private var backgroundImagePath: String?

    // Track the original style ID when loading
    private var currentStyleId: UUID?

    // MARK: - Initialization

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupControls()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupControls()
    }

    // MARK: - Setup

    private func setupControls() {
        let padding: CGFloat = 20
        var y = frame.height - 10

        // Position
        y -= 28
        let posLabel = createLabel("Position:")
        posLabel.frame = NSRect(x: padding, y: y, width: 80, height: 22)
        addSubview(posLabel)

        positionPopup = NSPopUpButton(frame: NSRect(x: padding + 85, y: y, width: 140, height: 26), pullsDown: false)
        positionPopup.addItems(withTitles: [
            "Top Left", "Top Center", "Top Right",
            "Middle Left", "Center", "Middle Right",
            "Bottom Left", "Bottom Center", "Bottom Right"
        ])
        addSubview(positionPopup)

        // Offset
        y -= 28
        let offsetLabel = createLabel("Offset:")
        offsetLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        addSubview(offsetLabel)

        let xLabel = createLabel("X:")
        xLabel.frame = NSRect(x: padding + 55, y: y, width: 20, height: 22)
        addSubview(xLabel)

        offsetXField = NSTextField(frame: NSRect(x: padding + 75, y: y, width: 45, height: 22))
        addSubview(offsetXField)

        let yLabel = createLabel("Y:")
        yLabel.frame = NSRect(x: padding + 130, y: y, width: 20, height: 22)
        addSubview(yLabel)

        offsetYField = NSTextField(frame: NSRect(x: padding + 150, y: y, width: 45, height: 22))
        addSubview(offsetYField)

        let pxLabel = createLabel("px")
        pxLabel.frame = NSRect(x: padding + 200, y: y, width: 20, height: 22)
        addSubview(pxLabel)

        // Scale
        y -= 28
        let scaleTextLabel = createLabel("Scale:")
        scaleTextLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        addSubview(scaleTextLabel)

        scaleSlider = NSSlider(frame: NSRect(x: padding + 55, y: y, width: 180, height: 22))
        scaleSlider.minValue = 0.5
        scaleSlider.maxValue = 3.0
        scaleSlider.target = self
        scaleSlider.action = #selector(scaleChanged)
        addSubview(scaleSlider)

        scaleLabel = createLabel("1.5x")
        scaleLabel.frame = NSRect(x: padding + 240, y: y, width: 40, height: 22)
        addSubview(scaleLabel)

        // Opacity
        y -= 28
        let opacityTextLabel = createLabel("Opacity:")
        opacityTextLabel.frame = NSRect(x: padding, y: y, width: 55, height: 22)
        addSubview(opacityTextLabel)

        opacitySlider = NSSlider(frame: NSRect(x: padding + 55, y: y, width: 180, height: 22))
        opacitySlider.minValue = 0.1
        opacitySlider.maxValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        addSubview(opacitySlider)

        opacityLabel = createLabel("95%")
        opacityLabel.frame = NSRect(x: padding + 240, y: y, width: 40, height: 22)
        addSubview(opacityLabel)

        // Display time
        y -= 28
        let dwellLabel = createLabel("Display:")
        dwellLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        addSubview(dwellLabel)

        dwellField = NSTextField(frame: NSRect(x: padding + 55, y: y, width: 45, height: 22))
        addSubview(dwellField)

        let secLabel = createLabel("seconds")
        secLabel.frame = NSRect(x: padding + 105, y: y, width: 55, height: 22)
        addSubview(secLabel)

        // Colors
        y -= 35
        let colorsLabel = createLabel("Colors:")
        colorsLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        addSubview(colorsLabel)

        let bgLabel = createLabel("BG")
        bgLabel.frame = NSRect(x: padding + 55, y: y, width: 22, height: 22)
        addSubview(bgLabel)

        bgColorWell = NSColorWell(frame: NSRect(x: padding + 77, y: y, width: 32, height: 22))
        addSubview(bgColorWell)

        let titleCLabel = createLabel("Title")
        titleCLabel.frame = NSRect(x: padding + 120, y: y, width: 30, height: 22)
        addSubview(titleCLabel)

        titleColorWell = NSColorWell(frame: NSRect(x: padding + 152, y: y, width: 32, height: 22))
        addSubview(titleColorWell)

        let subtitleCLabel = createLabel("Subtitle")
        subtitleCLabel.frame = NSRect(x: padding + 195, y: y, width: 45, height: 22)
        addSubview(subtitleCLabel)

        subtitleColorWell = NSColorWell(frame: NSRect(x: padding + 242, y: y, width: 32, height: 22))
        addSubview(subtitleColorWell)

        let bodyCLabel = createLabel("Body")
        bodyCLabel.frame = NSRect(x: padding + 285, y: y, width: 32, height: 22)
        addSubview(bodyCLabel)

        bodyColorWell = NSColorWell(frame: NSRect(x: padding + 319, y: y, width: 32, height: 22))
        addSubview(bodyColorWell)

        // App name row: checkbox + color
        y -= 35
        showAppNameCheckbox = NSButton(checkboxWithTitle: "Show app name", target: nil, action: nil)
        showAppNameCheckbox.frame = NSRect(x: padding, y: y, width: 130, height: 20)
        addSubview(showAppNameCheckbox)

        let appCLabel = createLabel("App Color:")
        appCLabel.frame = NSRect(x: padding + 140, y: y, width: 65, height: 22)
        addSubview(appCLabel)

        appColorWell = NSColorWell(frame: NSRect(x: padding + 205, y: y, width: 32, height: 22))
        addSubview(appColorWell)

        // Custom Icon
        y -= 45
        let iconLabel = createLabel("Custom Icon:")
        iconLabel.frame = NSRect(x: padding, y: y, width: 85, height: 22)
        addSubview(iconLabel)

        iconImageView = NSImageView(frame: NSRect(x: padding + 90, y: y - 10, width: 40, height: 40))
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 20
        iconImageView.layer?.masksToBounds = true
        iconImageView.layer?.borderWidth = 1
        iconImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(iconImageView)

        let chooseButton = NSButton(title: "Choose...", target: self, action: #selector(chooseIcon))
        chooseButton.bezelStyle = .rounded
        chooseButton.frame = NSRect(x: padding + 140, y: y - 2, width: 80, height: 24)
        addSubview(chooseButton)

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearIcon))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: padding + 225, y: y - 2, width: 60, height: 24)
        addSubview(clearButton)

        let iconHint = createLabel("Square recommended (e.g. 128x128)")
        iconHint.font = NSFont.systemFont(ofSize: 10)
        iconHint.textColor = .secondaryLabelColor
        iconHint.frame = NSRect(x: padding + 90, y: y - 30, width: 200, height: 14)
        addSubview(iconHint)

        // Background Image
        y -= 60
        let bgImageLabel = createLabel("Background:")
        bgImageLabel.frame = NSRect(x: padding, y: y, width: 85, height: 22)
        addSubview(bgImageLabel)

        bgImageView = NSImageView(frame: NSRect(x: padding + 90, y: y - 10, width: 60, height: 40))
        bgImageView.imageScaling = .scaleProportionallyUpOrDown
        bgImageView.wantsLayer = true
        bgImageView.layer?.cornerRadius = 4
        bgImageView.layer?.masksToBounds = true
        bgImageView.layer?.borderWidth = 1
        bgImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(bgImageView)

        let chooseBgButton = NSButton(title: "Choose...", target: self, action: #selector(chooseBackgroundImage))
        chooseBgButton.bezelStyle = .rounded
        chooseBgButton.frame = NSRect(x: padding + 160, y: y - 2, width: 80, height: 24)
        addSubview(chooseBgButton)

        let clearBgButton = NSButton(title: "Clear", target: self, action: #selector(clearBackgroundImage))
        clearBgButton.bezelStyle = .rounded
        clearBgButton.frame = NSRect(x: padding + 245, y: y - 2, width: 60, height: 24)
        addSubview(clearBgButton)

        let bgHint = createLabel("16:9 or wider recommended")
        bgHint.font = NSFont.systemFont(ofSize: 10)
        bgHint.textColor = .secondaryLabelColor
        bgHint.frame = NSRect(x: padding + 90, y: y - 30, width: 200, height: 14)
        addSubview(bgHint)

        // Border
        y -= 50
        let borderLabel = createLabel("Border:")
        borderLabel.frame = NSRect(x: padding, y: y, width: 50, height: 22)
        addSubview(borderLabel)

        borderWidthSlider = NSSlider(value: 0, minValue: 0, maxValue: 4, target: self, action: #selector(borderWidthChanged))
        borderWidthSlider.frame = NSRect(x: padding + 55, y: y, width: 100, height: 22)
        borderWidthSlider.numberOfTickMarks = 5
        borderWidthSlider.allowsTickMarkValuesOnly = true
        addSubview(borderWidthSlider)

        borderWidthLabel = createLabel("0px")
        borderWidthLabel.frame = NSRect(x: padding + 160, y: y, width: 35, height: 22)
        addSubview(borderWidthLabel)

        let borderColorLabel = createLabel("Color:")
        borderColorLabel.frame = NSRect(x: padding + 200, y: y, width: 40, height: 22)
        addSubview(borderColorLabel)

        borderColorWell = NSColorWell(frame: NSRect(x: padding + 242, y: y, width: 32, height: 22))
        borderColorWell.color = .white
        addSubview(borderColorWell)

        // Animation
        y -= 35
        let animationLabel = createLabel("Animation:")
        animationLabel.frame = NSRect(x: padding, y: y, width: 65, height: 22)
        addSubview(animationLabel)

        animationPopup = NSPopUpButton(frame: NSRect(x: padding + 70, y: y, width: 120, height: 26), pullsDown: false)
        animationPopup.addItems(withTitles: ["None", "Pulse", "Jiggle", "Bounce"])
        animationPopup.selectItem(at: 0)
        addSubview(animationPopup)

        // Load defaults
        loadStyleIntoControls(NotificationStyle())
    }

    // MARK: - Style Loading/Building

    private func loadStyleIntoControls(_ style: NotificationStyle) {
        currentStyleId = style.id

        positionPopup.selectItem(at: cornerToIndex(style.position))
        offsetXField.stringValue = String(Int(style.offsetX))
        offsetYField.stringValue = String(Int(style.offsetY))
        scaleSlider.doubleValue = style.scale
        scaleLabel.stringValue = String(format: "%.1fx", style.scale)
        opacitySlider.doubleValue = style.opacity
        opacityLabel.stringValue = String(format: "%.0f%%", style.opacity * 100)
        dwellField.stringValue = String(Int(style.dwellTime))

        bgColorWell.color = colorFromHex(style.backgroundColorHex)
        appColorWell.color = colorFromHex(style.appColorHex)
        titleColorWell.color = colorFromHex(style.titleColorHex)
        subtitleColorWell.color = colorFromHex(style.subtitleColorHex)
        bodyColorWell.color = colorFromHex(style.bodyColorHex)

        // Load custom icon
        customIconPath = style.customIconPath
        if let path = customIconPath, !path.isEmpty {
            iconImageView.image = NSImage(contentsOfFile: path)
        } else {
            iconImageView.image = nil
        }

        // Load background image
        backgroundImagePath = style.backgroundImagePath
        if let path = backgroundImagePath, !path.isEmpty {
            bgImageView.image = NSImage(contentsOfFile: path)
        } else {
            bgImageView.image = nil
        }

        showAppNameCheckbox.state = style.showAppName ? .on : .off

        borderWidthSlider.doubleValue = style.borderWidth
        borderWidthLabel.stringValue = "\(Int(style.borderWidth))px"
        borderColorWell.color = colorFromHex(style.borderColorHex)

        animationPopup.selectItem(at: animationToIndex(style.animation))
    }

    private func buildStyleFromControls() -> NotificationStyle {
        var style = NotificationStyle()
        style.id = currentStyleId ?? UUID()
        style.position = indexToCorner(positionPopup.indexOfSelectedItem)
        style.offsetX = Double(offsetXField.stringValue) ?? 20
        style.offsetY = Double(offsetYField.stringValue) ?? 20
        style.scale = scaleSlider.doubleValue
        style.opacity = opacitySlider.doubleValue
        style.dwellTime = Double(dwellField.stringValue) ?? 5
        style.backgroundColorHex = hexFromColor(bgColorWell.color)
        style.appColorHex = hexFromColor(appColorWell.color)
        style.titleColorHex = hexFromColor(titleColorWell.color)
        style.subtitleColorHex = hexFromColor(subtitleColorWell.color)
        style.bodyColorHex = hexFromColor(bodyColorWell.color)
        style.customIconPath = customIconPath
        style.backgroundImagePath = backgroundImagePath
        style.showAppName = showAppNameCheckbox.state == .on
        style.borderWidth = borderWidthSlider.doubleValue
        style.borderColorHex = hexFromColor(borderColorWell.color)
        style.animation = indexToAnimation(animationPopup.indexOfSelectedItem)
        return style
    }

    // MARK: - Actions

    @objc private func scaleChanged() {
        scaleLabel.stringValue = String(format: "%.1fx", scaleSlider.doubleValue)
    }

    @objc private func opacityChanged() {
        opacityLabel.stringValue = String(format: "%.0f%%", opacitySlider.doubleValue * 100)
    }

    @objc private func borderWidthChanged() {
        let width = Int(borderWidthSlider.doubleValue)
        borderWidthLabel.stringValue = "\(width)px"
    }

    @objc private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an icon image (recommended: square, e.g. 128x128)"

        guard let win = parentWindow else { return }
        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.customIconPath = url.path
                self?.iconImageView.image = NSImage(contentsOf: url)
            }
        }
    }

    @objc private func clearIcon() {
        customIconPath = nil
        iconImageView.image = nil
    }

    @objc private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a background image (recommended: 16:9 or wider)"

        guard let win = parentWindow else { return }
        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.backgroundImagePath = url.path
                self?.bgImageView.image = NSImage(contentsOf: url)
            }
        }
    }

    @objc private func clearBackgroundImage() {
        backgroundImagePath = nil
        bgImageView.image = nil
    }

    // MARK: - Helpers

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 12)
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    private func cornerToIndex(_ corner: String) -> Int {
        switch corner {
        case "topLeft": return 0
        case "topCenter": return 1
        case "topRight": return 2
        case "middleLeft": return 3
        case "center": return 4
        case "middleRight": return 5
        case "bottomLeft": return 6
        case "bottomCenter": return 7
        case "bottomRight": return 8
        default: return 6
        }
    }

    private func indexToCorner(_ index: Int) -> String {
        switch index {
        case 0: return "topLeft"
        case 1: return "topCenter"
        case 2: return "topRight"
        case 3: return "middleLeft"
        case 4: return "center"
        case 5: return "middleRight"
        case 6: return "bottomLeft"
        case 7: return "bottomCenter"
        case 8: return "bottomRight"
        default: return "bottomLeft"
        }
    }

    private func animationToIndex(_ animation: String) -> Int {
        switch animation {
        case "pulse": return 1
        case "jiggle": return 2
        case "bounce": return 3
        default: return 0
        }
    }

    private func indexToAnimation(_ index: Int) -> String {
        switch index {
        case 1: return "pulse"
        case 2: return "jiggle"
        case 3: return "bounce"
        default: return "none"
        }
    }

    private func colorFromHex(_ hex: String) -> NSColor {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleanHex.count == 6 else { return .black }

        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func hexFromColor(_ color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return "000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
