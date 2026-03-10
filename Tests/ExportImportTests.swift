import XCTest
@testable import NotifyMeHow

final class ExportImportTests: XCTestCase {

    // MARK: - NotificationStyle Codable Tests

    func testNotificationStyleEncodesAllFields() throws {
        var style = NotificationStyle()
        style.id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        style.name = "Test Style"
        style.position = "topRight"
        style.offsetX = 30
        style.offsetY = 50
        style.scale = 2.0
        style.opacity = 0.8
        style.dwellTime = 7.5
        style.backgroundColorHex = "FF0000"
        style.appColorHex = "00FF00"
        style.titleColorHex = "0000FF"
        style.subtitleColorHex = "FFFF00"
        style.bodyColorHex = "FF00FF"
        style.customIconPath = "/path/to/icon.png"
        style.backgroundImagePath = "/path/to/bg.png"
        style.showAppName = true
        style.borderWidth = 3.0
        style.borderColorHex = "AABBCC"
        style.animation = "pulse"
        style.animationLoops = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(style)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["id"] as? String, "12345678-1234-1234-1234-123456789ABC")
        XCTAssertEqual(json["name"] as? String, "Test Style")
        XCTAssertEqual(json["position"] as? String, "topRight")
        XCTAssertEqual(json["offsetX"] as? Double, 30)
        XCTAssertEqual(json["offsetY"] as? Double, 50)
        XCTAssertEqual(json["scale"] as? Double, 2.0)
        XCTAssertEqual(json["opacity"] as? Double, 0.8)
        XCTAssertEqual(json["dwellTime"] as? Double, 7.5)
        XCTAssertEqual(json["backgroundColorHex"] as? String, "FF0000")
        XCTAssertEqual(json["appColorHex"] as? String, "00FF00")
        XCTAssertEqual(json["titleColorHex"] as? String, "0000FF")
        XCTAssertEqual(json["subtitleColorHex"] as? String, "FFFF00")
        XCTAssertEqual(json["bodyColorHex"] as? String, "FF00FF")
        XCTAssertEqual(json["customIconPath"] as? String, "/path/to/icon.png")
        XCTAssertEqual(json["backgroundImagePath"] as? String, "/path/to/bg.png")
        XCTAssertEqual(json["showAppName"] as? Bool, true)
        XCTAssertEqual(json["borderWidth"] as? Double, 3.0)
        XCTAssertEqual(json["borderColorHex"] as? String, "AABBCC")
        XCTAssertEqual(json["animation"] as? String, "pulse")
        XCTAssertEqual(json["animationLoops"] as? Bool, true)
    }

    func testNotificationStyleDecodesAllFields() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789ABC",
            "name": "Decoded Style",
            "position": "bottomRight",
            "offsetX": 25,
            "offsetY": 35,
            "scale": 1.75,
            "opacity": 0.9,
            "dwellTime": 6.0,
            "backgroundColorHex": "112233",
            "appColorHex": "445566",
            "titleColorHex": "778899",
            "subtitleColorHex": "AABBCC",
            "bodyColorHex": "DDEEFF",
            "customIconPath": "/custom/icon.png",
            "backgroundImagePath": "/custom/bg.jpg",
            "showAppName": true,
            "borderWidth": 2.5,
            "borderColorHex": "FEDCBA",
            "animation": "wiggle",
            "animationLoops": true
        }
        """

        let data = json.data(using: .utf8)!
        let style = try JSONDecoder().decode(NotificationStyle.self, from: data)

        XCTAssertEqual(style.id.uuidString, "12345678-1234-1234-1234-123456789ABC")
        XCTAssertEqual(style.name, "Decoded Style")
        XCTAssertEqual(style.position, "bottomRight")
        XCTAssertEqual(style.offsetX, 25)
        XCTAssertEqual(style.offsetY, 35)
        XCTAssertEqual(style.scale, 1.75)
        XCTAssertEqual(style.opacity, 0.9)
        XCTAssertEqual(style.dwellTime, 6.0)
        XCTAssertEqual(style.backgroundColorHex, "112233")
        XCTAssertEqual(style.appColorHex, "445566")
        XCTAssertEqual(style.titleColorHex, "778899")
        XCTAssertEqual(style.subtitleColorHex, "AABBCC")
        XCTAssertEqual(style.bodyColorHex, "DDEEFF")
        XCTAssertEqual(style.customIconPath, "/custom/icon.png")
        XCTAssertEqual(style.backgroundImagePath, "/custom/bg.jpg")
        XCTAssertEqual(style.showAppName, true)
        XCTAssertEqual(style.borderWidth, 2.5)
        XCTAssertEqual(style.borderColorHex, "FEDCBA")
        XCTAssertEqual(style.animation, "wiggle")
        XCTAssertEqual(style.animationLoops, true)
    }

    func testNotificationStyleRoundTrip() throws {
        var original = NotificationStyle()
        original.name = "Round Trip"
        original.position = "topLeft"
        original.offsetX = 100
        original.offsetY = 200
        original.scale = 3.0
        original.opacity = 0.5
        original.dwellTime = 10.0
        original.backgroundColorHex = "ABCDEF"
        original.appColorHex = "123456"
        original.titleColorHex = "789ABC"
        original.subtitleColorHex = "DEF012"
        original.bodyColorHex = "345678"
        original.customIconPath = "/round/trip/icon.png"
        original.backgroundImagePath = "/round/trip/bg.png"
        original.showAppName = true
        original.borderWidth = 5.0
        original.borderColorHex = "9ABCDE"
        original.animation = "bounce"
        original.animationLoops = false

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationStyle.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.position, original.position)
        XCTAssertEqual(decoded.offsetX, original.offsetX)
        XCTAssertEqual(decoded.offsetY, original.offsetY)
        XCTAssertEqual(decoded.scale, original.scale)
        XCTAssertEqual(decoded.opacity, original.opacity)
        XCTAssertEqual(decoded.dwellTime, original.dwellTime)
        XCTAssertEqual(decoded.backgroundColorHex, original.backgroundColorHex)
        XCTAssertEqual(decoded.appColorHex, original.appColorHex)
        XCTAssertEqual(decoded.titleColorHex, original.titleColorHex)
        XCTAssertEqual(decoded.subtitleColorHex, original.subtitleColorHex)
        XCTAssertEqual(decoded.bodyColorHex, original.bodyColorHex)
        XCTAssertEqual(decoded.customIconPath, original.customIconPath)
        XCTAssertEqual(decoded.backgroundImagePath, original.backgroundImagePath)
        XCTAssertEqual(decoded.showAppName, original.showAppName)
        XCTAssertEqual(decoded.borderWidth, original.borderWidth)
        XCTAssertEqual(decoded.borderColorHex, original.borderColorHex)
        XCTAssertEqual(decoded.animation, original.animation)
        XCTAssertEqual(decoded.animationLoops, original.animationLoops)
    }

    // MARK: - NotificationRule Codable Tests

    func testNotificationRuleEncodesAllFields() throws {
        var rule = NotificationRule()
        rule.id = UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890")!
        rule.name = "Test Rule"
        rule.criteria.appName = "Slack"
        rule.criteria.titleContains = "urgent"
        rule.criteria.bodyContains = "meeting"
        rule.styleId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        rule.enabled = false

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["id"] as? String, "ABCDEF12-3456-7890-ABCD-EF1234567890")
        XCTAssertEqual(json["name"] as? String, "Test Rule")
        XCTAssertEqual(json["styleId"] as? String, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(json["enabled"] as? Bool, false)

        let criteria = json["criteria"] as! [String: Any]
        XCTAssertEqual(criteria["appName"] as? String, "Slack")
        XCTAssertEqual(criteria["titleContains"] as? String, "urgent")
        XCTAssertEqual(criteria["bodyContains"] as? String, "meeting")
    }

    func testNotificationRuleDecodesAllFields() throws {
        let json = """
        {
            "id": "ABCDEF12-3456-7890-ABCD-EF1234567890",
            "name": "Decoded Rule",
            "criteria": {
                "appName": "Messages",
                "titleContains": "from",
                "bodyContains": "hello"
            },
            "styleId": "22222222-3333-4444-5555-666666666666",
            "enabled": true
        }
        """

        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(NotificationRule.self, from: data)

        XCTAssertEqual(rule.id.uuidString, "ABCDEF12-3456-7890-ABCD-EF1234567890")
        XCTAssertEqual(rule.name, "Decoded Rule")
        XCTAssertEqual(rule.criteria.appName, "Messages")
        XCTAssertEqual(rule.criteria.titleContains, "from")
        XCTAssertEqual(rule.criteria.bodyContains, "hello")
        XCTAssertEqual(rule.styleId?.uuidString, "22222222-3333-4444-5555-666666666666")
        XCTAssertEqual(rule.enabled, true)
    }

    func testNotificationRuleRoundTrip() throws {
        var original = NotificationRule()
        original.name = "Round Trip Rule"
        original.criteria.appName = "Calendar"
        original.criteria.titleContains = "reminder"
        original.criteria.bodyContains = "event"
        original.styleId = UUID()
        original.enabled = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationRule.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.criteria.appName, original.criteria.appName)
        XCTAssertEqual(decoded.criteria.titleContains, original.criteria.titleContains)
        XCTAssertEqual(decoded.criteria.bodyContains, original.criteria.bodyContains)
        XCTAssertEqual(decoded.styleId, original.styleId)
        XCTAssertEqual(decoded.enabled, original.enabled)
    }

    func testNotificationRuleWithNilStyleId() throws {
        var rule = NotificationRule()
        rule.name = "No Style Rule"
        rule.styleId = nil

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationRule.self, from: data)

        XCTAssertNil(decoded.styleId)
    }

    // MARK: - ExportData Codable Tests

    func testExportDataEncodesAllFields() throws {
        let style = NotificationStyle(name: "Export Test Style")
        var rule = NotificationRule()
        rule.name = "Export Test Rule"
        rule.styleId = style.id

        let settingsExport = Settings.SettingsExport(
            positionCorner: "topRight",
            positionOffsetX: 20,
            positionOffsetY: 40,
            scaleFactor: 1.0,
            autoStartMonitoring: true,
            launchAtLogin: false
        )

        let exportData = Settings.ExportData(
            version: 1,
            settings: settingsExport,
            styles: [style],
            rules: [rule],
            defaultBehavior: "noCustom"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(exportData)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["defaultBehavior"] as? String, "noCustom")

        let settings = json["settings"] as! [String: Any]
        XCTAssertEqual(settings["positionCorner"] as? String, "topRight")
        XCTAssertEqual(settings["positionOffsetX"] as? Double, 20)
        XCTAssertEqual(settings["positionOffsetY"] as? Double, 40)
        XCTAssertEqual(settings["scaleFactor"] as? Double, 1.0)
        XCTAssertEqual(settings["autoStartMonitoring"] as? Bool, true)
        XCTAssertEqual(settings["launchAtLogin"] as? Bool, false)

        let styles = json["styles"] as! [[String: Any]]
        XCTAssertEqual(styles.count, 1)
        XCTAssertEqual(styles[0]["name"] as? String, "Export Test Style")

        let rules = json["rules"] as! [[String: Any]]
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0]["name"] as? String, "Export Test Rule")
    }

    func testExportDataDecodesAllFields() throws {
        let json = """
        {
            "version": 1,
            "settings": {
                "positionCorner": "bottomLeft",
                "positionOffsetX": 15,
                "positionOffsetY": 25,
                "scaleFactor": 1.5,
                "autoStartMonitoring": false,
                "launchAtLogin": true
            },
            "styles": [
                {
                    "id": "11111111-1111-1111-1111-111111111111",
                    "name": "Imported Style",
                    "position": "topRight",
                    "offsetX": 30,
                    "offsetY": 40,
                    "scale": 2.0,
                    "opacity": 0.85,
                    "dwellTime": 5.0,
                    "backgroundColorHex": "1A1A1A",
                    "appColorHex": "AAAAAA",
                    "titleColorHex": "FFFFFF",
                    "subtitleColorHex": "DDDDDD",
                    "bodyColorHex": "DDDDDD",
                    "showAppName": false,
                    "borderWidth": 0,
                    "borderColorHex": "FFFFFF",
                    "animation": "none",
                    "animationLoops": false
                }
            ],
            "rules": [
                {
                    "id": "22222222-2222-2222-2222-222222222222",
                    "name": "Imported Rule",
                    "criteria": {
                        "appName": "Mail",
                        "titleContains": "",
                        "bodyContains": ""
                    },
                    "styleId": "11111111-1111-1111-1111-111111111111",
                    "enabled": true
                }
            ],
            "defaultBehavior": "showCustom"
        }
        """

        let data = json.data(using: .utf8)!
        let exportData = try JSONDecoder().decode(Settings.ExportData.self, from: data)

        XCTAssertEqual(exportData.version, 1)
        XCTAssertEqual(exportData.defaultBehavior, "showCustom")

        XCTAssertEqual(exportData.settings.positionCorner, "bottomLeft")
        XCTAssertEqual(exportData.settings.positionOffsetX, 15)
        XCTAssertEqual(exportData.settings.positionOffsetY, 25)
        XCTAssertEqual(exportData.settings.scaleFactor, 1.5)
        XCTAssertEqual(exportData.settings.autoStartMonitoring, false)
        XCTAssertEqual(exportData.settings.launchAtLogin, true)

        XCTAssertEqual(exportData.styles.count, 1)
        XCTAssertEqual(exportData.styles[0].name, "Imported Style")
        XCTAssertEqual(exportData.styles[0].position, "topRight")
        XCTAssertEqual(exportData.styles[0].scale, 2.0)

        XCTAssertEqual(exportData.rules.count, 1)
        XCTAssertEqual(exportData.rules[0].name, "Imported Rule")
        XCTAssertEqual(exportData.rules[0].criteria.appName, "Mail")
        XCTAssertEqual(exportData.rules[0].styleId?.uuidString, "11111111-1111-1111-1111-111111111111")
    }

    func testExportDataRoundTrip() throws {
        var style1 = NotificationStyle(name: "Style One")
        style1.position = "topLeft"
        style1.scale = 1.25
        style1.animation = "pulse"
        style1.animationLoops = true
        style1.borderWidth = 2.0
        style1.borderColorHex = "FF0000"

        var style2 = NotificationStyle(name: "Style Two")
        style2.position = "bottomRight"
        style2.opacity = 0.7
        style2.showAppName = true

        var rule1 = NotificationRule()
        rule1.name = "Rule One"
        rule1.criteria.appName = "Finder"
        rule1.styleId = style1.id

        var rule2 = NotificationRule()
        rule2.name = "Rule Two"
        rule2.criteria.titleContains = "alert"
        rule2.styleId = style2.id
        rule2.enabled = false

        let settingsExport = Settings.SettingsExport(
            positionCorner: "center",
            positionOffsetX: 0,
            positionOffsetY: 100,
            scaleFactor: 0.75,
            autoStartMonitoring: false,
            launchAtLogin: true
        )

        let original = Settings.ExportData(
            version: 1,
            settings: settingsExport,
            styles: [style1, style2],
            rules: [rule1, rule2],
            defaultBehavior: "showCustom"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Settings.ExportData.self, from: data)

        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.defaultBehavior, original.defaultBehavior)

        XCTAssertEqual(decoded.settings.positionCorner, original.settings.positionCorner)
        XCTAssertEqual(decoded.settings.positionOffsetX, original.settings.positionOffsetX)
        XCTAssertEqual(decoded.settings.positionOffsetY, original.settings.positionOffsetY)
        XCTAssertEqual(decoded.settings.scaleFactor, original.settings.scaleFactor)
        XCTAssertEqual(decoded.settings.autoStartMonitoring, original.settings.autoStartMonitoring)
        XCTAssertEqual(decoded.settings.launchAtLogin, original.settings.launchAtLogin)

        XCTAssertEqual(decoded.styles.count, 2)
        XCTAssertEqual(decoded.styles[0].name, "Style One")
        XCTAssertEqual(decoded.styles[0].animation, "pulse")
        XCTAssertEqual(decoded.styles[0].animationLoops, true)
        XCTAssertEqual(decoded.styles[1].name, "Style Two")
        XCTAssertEqual(decoded.styles[1].showAppName, true)

        XCTAssertEqual(decoded.rules.count, 2)
        XCTAssertEqual(decoded.rules[0].name, "Rule One")
        XCTAssertEqual(decoded.rules[0].criteria.appName, "Finder")
        XCTAssertEqual(decoded.rules[1].name, "Rule Two")
        XCTAssertEqual(decoded.rules[1].enabled, false)
    }

    // MARK: - Edge Cases

    func testStyleWithOptionalFieldsNil() throws {
        var style = NotificationStyle(name: "Minimal")
        style.customIconPath = nil
        style.backgroundImagePath = nil

        let encoder = JSONEncoder()
        let data = try encoder.encode(style)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationStyle.self, from: data)

        XCTAssertNil(decoded.customIconPath)
        XCTAssertNil(decoded.backgroundImagePath)
    }

    func testEmptyStylesAndRules() throws {
        let settingsExport = Settings.SettingsExport(
            positionCorner: "topRight",
            positionOffsetX: 20,
            positionOffsetY: 40,
            scaleFactor: 1.0,
            autoStartMonitoring: true,
            launchAtLogin: false
        )

        let exportData = Settings.ExportData(
            version: 1,
            settings: settingsExport,
            styles: [],
            rules: [],
            defaultBehavior: "noCustom"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(exportData)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Settings.ExportData.self, from: data)

        XCTAssertEqual(decoded.styles.count, 0)
        XCTAssertEqual(decoded.rules.count, 0)
    }

    func testMultipleStylesWithSameProperties() throws {
        var style1 = NotificationStyle(name: "Copy 1")
        style1.backgroundColorHex = "123456"
        style1.animation = "jiggle"

        var style2 = NotificationStyle(name: "Copy 2")
        style2.backgroundColorHex = "123456"
        style2.animation = "jiggle"

        let encoder = JSONEncoder()
        let data = try encoder.encode([style1, style2])

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([NotificationStyle].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertNotEqual(decoded[0].id, decoded[1].id)
        XCTAssertEqual(decoded[0].backgroundColorHex, decoded[1].backgroundColorHex)
    }

    func testAllAnimationTypes() throws {
        let animations = ["none", "pulse", "jiggle", "wiggle", "bounce"]

        for animation in animations {
            var style = NotificationStyle(name: "Animation Test")
            style.animation = animation

            let encoder = JSONEncoder()
            let data = try encoder.encode(style)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(NotificationStyle.self, from: data)

            XCTAssertEqual(decoded.animation, animation, "Failed for animation: \(animation)")
        }
    }

    func testAllCornerPositions() throws {
        let positions = ["topLeft", "topCenter", "topRight", "centerLeft", "center", "centerRight", "bottomLeft", "bottomCenter", "bottomRight"]

        for position in positions {
            var style = NotificationStyle(name: "Position Test")
            style.position = position

            let encoder = JSONEncoder()
            let data = try encoder.encode(style)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(NotificationStyle.self, from: data)

            XCTAssertEqual(decoded.position, position, "Failed for position: \(position)")
        }
    }

    func testRuleWithEmptyCriteria() throws {
        var rule = NotificationRule()
        rule.name = "Match All"
        rule.criteria.appName = ""
        rule.criteria.titleContains = ""
        rule.criteria.bodyContains = ""

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationRule.self, from: data)

        XCTAssertTrue(decoded.criteria.isEmpty)
    }

    func testSpecialCharactersInStrings() throws {
        var style = NotificationStyle()
        style.name = "Test \"quoted\" & <special> chars"

        var rule = NotificationRule()
        rule.name = "Rule with 'quotes'"
        rule.criteria.appName = "App & More"
        rule.criteria.titleContains = "<html>"

        let encoder = JSONEncoder()
        let styleData = try encoder.encode(style)
        let ruleData = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decodedStyle = try decoder.decode(NotificationStyle.self, from: styleData)
        let decodedRule = try decoder.decode(NotificationRule.self, from: ruleData)

        XCTAssertEqual(decodedStyle.name, "Test \"quoted\" & <special> chars")
        XCTAssertEqual(decodedRule.name, "Rule with 'quotes'")
        XCTAssertEqual(decodedRule.criteria.appName, "App & More")
        XCTAssertEqual(decodedRule.criteria.titleContains, "<html>")
    }

    func testUnicodeInStrings() throws {
        var style = NotificationStyle()
        style.name = "日本語スタイル 🎨"

        var rule = NotificationRule()
        rule.name = "Règle française"
        rule.criteria.appName = "Приложение"

        let encoder = JSONEncoder()
        let styleData = try encoder.encode(style)
        let ruleData = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decodedStyle = try decoder.decode(NotificationStyle.self, from: styleData)
        let decodedRule = try decoder.decode(NotificationRule.self, from: ruleData)

        XCTAssertEqual(decodedStyle.name, "日本語スタイル 🎨")
        XCTAssertEqual(decodedRule.name, "Règle française")
        XCTAssertEqual(decodedRule.criteria.appName, "Приложение")
    }

    func testExtremeNumericValues() throws {
        var style = NotificationStyle()
        style.offsetX = 10000
        style.offsetY = -500
        style.scale = 0.01
        style.opacity = 0.001
        style.dwellTime = 3600  // 1 hour
        style.borderWidth = 100

        let encoder = JSONEncoder()
        let data = try encoder.encode(style)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationStyle.self, from: data)

        XCTAssertEqual(decoded.offsetX, 10000)
        XCTAssertEqual(decoded.offsetY, -500)
        XCTAssertEqual(decoded.scale, 0.01)
        XCTAssertEqual(decoded.opacity, 0.001)
        XCTAssertEqual(decoded.dwellTime, 3600)
        XCTAssertEqual(decoded.borderWidth, 100)
    }
}
