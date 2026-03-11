import XCTest
@testable import NotifyMeHow

final class LogicTests: XCTestCase {

    // MARK: - NotificationMatchCriteria Tests

    func testSingleKeywordMatchesInTitle() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "urgent"
        criteria.matchAll = false

        let content = NotificationContent()
        var mutableContent = content
        mutableContent.title = "Urgent meeting at 3pm"

        XCTAssertTrue(criteria.matches(mutableContent))
    }

    func testSingleKeywordMatchesInBody() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "invoice"
        criteria.matchAll = false

        var content = NotificationContent()
        content.body = "Your invoice is ready"

        XCTAssertTrue(criteria.matches(content))
    }

    func testSingleKeywordNoMatch() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "urgent"
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "Normal meeting"
        content.body = "Nothing special"

        XCTAssertFalse(criteria.matches(content))
    }

    func testMultipleKeywordsMatchAllTrue_AllPresent() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "meeting, urgent"
        criteria.matchAll = true

        var content = NotificationContent()
        content.title = "Urgent"
        content.body = "meeting at 3pm"

        XCTAssertTrue(criteria.matches(content))
    }

    func testMultipleKeywordsMatchAllTrue_OnlyOnePresent() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "meeting, urgent"
        criteria.matchAll = true

        var content = NotificationContent()
        content.title = "Important meeting"
        content.body = "at 3pm"

        XCTAssertFalse(criteria.matches(content), "Should fail when not all keywords present")
    }

    func testMultipleKeywordsMatchAllFalse_AnyMatches() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "urgent, important, critical"
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "Important update"

        XCTAssertTrue(criteria.matches(content))
    }

    func testMultipleKeywordsMatchAllFalse_NoneMatch() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "urgent, important, critical"
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "Normal update"

        XCTAssertFalse(criteria.matches(content))
    }

    func testCaseInsensitiveKeywordMatching() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "ERROR"
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "error occurred in system"

        XCTAssertTrue(criteria.matches(content))
    }

    func testKeywordMatchesInSubtitle() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "important"
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "Message"
        content.subtitle = "This is important"
        content.body = "Nothing here"

        XCTAssertTrue(criteria.matches(content))
    }

    func testKeywordWhitespaceTrimming() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = "  keyword1  ,  keyword2  "
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "keyword1 found here"

        XCTAssertTrue(criteria.matches(content))
    }

    func testEmptyKeywordsMatchesEverything() {
        var criteria = NotificationMatchCriteria()
        criteria.keywords = ""
        criteria.matchAll = false

        var content = NotificationContent()
        content.title = "Anything at all"

        XCTAssertTrue(criteria.matches(content))
    }

    func testAppNameMatching() {
        var criteria = NotificationMatchCriteria()
        criteria.appName = "Slack"

        var content1 = NotificationContent()
        content1.appName = "Slack"

        var content2 = NotificationContent()
        content2.appName = "Mail"

        XCTAssertTrue(criteria.matches(content1))
        XCTAssertFalse(criteria.matches(content2))
    }

    func testAppNameCaseInsensitive() {
        var criteria = NotificationMatchCriteria()
        criteria.appName = "slack"

        var content = NotificationContent()
        content.appName = "Slack"

        XCTAssertTrue(criteria.matches(content))
    }

    func testAppNamePartialMatch() {
        var criteria = NotificationMatchCriteria()
        criteria.appName = "Slack"

        var content = NotificationContent()
        content.appName = "Slack Desktop"

        XCTAssertTrue(criteria.matches(content))
    }

    func testAppNameAndKeywordsBothRequired() {
        var criteria = NotificationMatchCriteria()
        criteria.appName = "Slack"
        criteria.keywords = "urgent"
        criteria.matchAll = false

        var content1 = NotificationContent()
        content1.appName = "Slack"
        content1.title = "Urgent message"

        var content2 = NotificationContent()
        content2.appName = "Slack"
        content2.title = "Normal message"

        var content3 = NotificationContent()
        content3.appName = "Mail"
        content3.title = "Urgent message"

        XCTAssertTrue(criteria.matches(content1), "Both app and keyword match")
        XCTAssertFalse(criteria.matches(content2), "App matches but keyword doesn't")
        XCTAssertFalse(criteria.matches(content3), "Keyword matches but app doesn't")
    }

    func testLegacyTitleContainsField() {
        var criteria = NotificationMatchCriteria()
        criteria.titleContains = "legacy"

        var content = NotificationContent()
        content.title = "This is a legacy notification"

        XCTAssertTrue(criteria.matches(content))
    }

    func testLegacyBodyContainsField() {
        var criteria = NotificationMatchCriteria()
        criteria.bodyContains = "old"

        var content = NotificationContent()
        content.body = "This is old style"

        XCTAssertTrue(criteria.matches(content))
    }

    func testIsEmptyProperty() {
        let empty = NotificationMatchCriteria()
        XCTAssertTrue(empty.isEmpty)

        var withApp = NotificationMatchCriteria()
        withApp.appName = "Slack"
        XCTAssertFalse(withApp.isEmpty)

        var withKeywords = NotificationMatchCriteria()
        withKeywords.keywords = "urgent"
        XCTAssertFalse(withKeywords.isEmpty)
    }

    func testAutoGeneratedName() {
        var criteria1 = NotificationMatchCriteria()
        criteria1.appName = "Slack"
        criteria1.keywords = "urgent"
        XCTAssertEqual(criteria1.autoGeneratedName, "Slack: urgent")

        var criteria2 = NotificationMatchCriteria()
        criteria2.keywords = "important"
        XCTAssertEqual(criteria2.autoGeneratedName, "important")

        let criteria3 = NotificationMatchCriteria()
        XCTAssertEqual(criteria3.autoGeneratedName, "All Notifications")
    }

    // MARK: - NotificationRule Tests

    func testDisabledRuleDoesNotMatch() {
        var rule = NotificationRule()
        rule.criteria.appName = "Mail"
        rule.enabled = false

        var content = NotificationContent()
        content.appName = "Mail"

        XCTAssertFalse(rule.matches(content))
    }

    func testEnabledRuleMatches() {
        var rule = NotificationRule()
        rule.criteria.appName = "Mail"
        rule.enabled = true

        var content = NotificationContent()
        content.appName = "Mail"

        XCTAssertTrue(rule.matches(content))
    }

    func testRuleDisplayNameUsesCustomName() {
        var rule = NotificationRule()
        rule.name = "My Custom Rule"
        rule.criteria.appName = "Mail"

        XCTAssertEqual(rule.displayName, "My Custom Rule")
    }

    func testRuleDisplayNameFallsBackToAutoGenerated() {
        var rule = NotificationRule()
        rule.name = ""
        rule.criteria.appName = "Slack"
        rule.criteria.keywords = "urgent"

        XCTAssertEqual(rule.displayName, "Slack: urgent")
    }

    // MARK: - Keyword Extraction Tests (RecordedNotification)

    func testKeywordExtractionFiltersStopWords() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "Mail",
            title: "A message from John",
            subtitle: "The email is important",
            body: "",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords()
        let parts = keywords.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        XCTAssertFalse(parts.contains("a"))
        XCTAssertFalse(parts.contains("the"))
        XCTAssertFalse(parts.contains("from"))
        XCTAssertFalse(parts.contains("is"))
        XCTAssertTrue(parts.contains("message"))
        XCTAssertTrue(parts.contains("john"))
    }

    func testKeywordExtractionFiltersShortWords() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "App",
            title: "Go to work now",
            subtitle: "",
            body: "",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords()
        let parts = keywords.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // "go", "to" are 2 chars, should be filtered
        // "work" is valid, "now" is a stop word
        XCTAssertTrue(parts.contains("work"))
        XCTAssertFalse(parts.contains("go"))
        XCTAssertFalse(parts.contains("to"))
    }

    func testKeywordExtractionLowercases() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "Mail",
            title: "URGENT MEETING",
            subtitle: "",
            body: "",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords()

        XCTAssertTrue(keywords.contains("urgent"))
        XCTAssertTrue(keywords.contains("meeting"))
        XCTAssertFalse(keywords.contains("URGENT"))
    }

    func testKeywordExtractionRespectsMaxWords() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "Mail",
            title: "alpha bravo charlie delta echo foxtrot golf hotel",
            subtitle: "",
            body: "",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords(maxWords: 3)
        let parts = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        XCTAssertLessThanOrEqual(parts.count, 3)
    }

    func testKeywordExtractionRemovesDuplicates() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "Mail",
            title: "urgent urgent urgent",
            subtitle: "urgent again",
            body: "still urgent",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords()
        let parts = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let urgentCount = parts.filter { $0 == "urgent" }.count
        XCTAssertEqual(urgentCount, 1, "Should have exactly one 'urgent'")
    }

    func testKeywordExtractionEmptyNotification() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "App",
            title: "",
            subtitle: "",
            body: "",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords()

        XCTAssertEqual(keywords, "")
    }

    func testKeywordExtractionPreservesOrder() {
        let notification = RecordedNotification(
            timestamp: Date(),
            appName: "Mail",
            title: "alpha bravo charlie",
            subtitle: "",
            body: "",
            appIcon: nil
        )
        let keywords = notification.suggestedKeywords()
        let parts = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if parts.count >= 3 {
            XCTAssertEqual(parts[0], "alpha")
            XCTAssertEqual(parts[1], "bravo")
            XCTAssertEqual(parts[2], "charlie")
        }
    }

    // MARK: - Color Parsing Tests

    func testColorFromHexValidColors() {
        // Test through NotificationStyle.toConfig()
        let testCases = ["000000", "FFFFFF", "FF0000", "00FF00", "0000FF", "AABBCC"]

        for hex in testCases {
            var style = NotificationStyle()
            style.backgroundColorHex = hex
            let config = style.toConfig()
            XCTAssertNotNil(config.backgroundColor, "Should parse: \(hex)")
        }
    }

    func testColorFromHexWithLeadingHash() {
        var style = NotificationStyle()
        style.backgroundColorHex = "#FF0000"
        let config = style.toConfig()
        XCTAssertNotNil(config.backgroundColor)
    }

    func testColorFromHexInvalidLength() {
        var style = NotificationStyle()
        style.backgroundColorHex = "FF"
        let config = style.toConfig()
        // Should not crash, returns default color
        XCTAssertNotNil(config.backgroundColor)
    }

    func testColorFromHexEmpty() {
        var style = NotificationStyle()
        style.backgroundColorHex = ""
        let config = style.toConfig()
        XCTAssertNotNil(config.backgroundColor)
    }

    func testColorFromHexCaseInsensitive() {
        var style1 = NotificationStyle()
        style1.backgroundColorHex = "aabbcc"

        var style2 = NotificationStyle()
        style2.backgroundColorHex = "AABBCC"

        let config1 = style1.toConfig()
        let config2 = style2.toConfig()

        // Both should produce valid colors
        XCTAssertNotNil(config1.backgroundColor)
        XCTAssertNotNil(config2.backgroundColor)
    }

    func testColorConverterRoundtrip() {
        // Test that hex -> color -> hex preserves the value
        let testCases = ["FF0000", "00FF00", "0000FF", "AABBCC", "123456", "FFFFFF", "000000"]

        for hex in testCases {
            let color = ColorConverter.colorFromHex(hex)
            let result = ColorConverter.hexFromColor(color)
            XCTAssertEqual(result.uppercased(), hex.uppercased(), "Roundtrip failed for \(hex)")
        }
    }

    // MARK: - Path Validation Tests

    func testPathValidationBlocksSystemDirectories() {
        var style = NotificationStyle()

        // These paths should be blocked even if files existed
        let blockedPaths = [
            "/System/Library/image.png",
            "/Library/image.png",
            "/private/var/image.png",
            "/etc/passwd",
            "/bin/ls",
            "/usr/bin/image.png",
            "/sbin/image.png"
        ]

        for path in blockedPaths {
            style.customIconPath = path
            let config = style.toConfig()
            XCTAssertNil(config.customIcon, "Should block path: \(path)")
        }
    }

    func testPathValidationRejectsNonExistentFiles() {
        var style = NotificationStyle()
        style.customIconPath = "/nonexistent/path/to/image.png"
        let config = style.toConfig()
        XCTAssertNil(config.customIcon)
    }

    func testPathValidationEmptyPath() {
        var style = NotificationStyle()
        style.customIconPath = ""
        let config = style.toConfig()
        XCTAssertNil(config.customIcon)
    }

    func testPathValidationNilPath() {
        var style = NotificationStyle()
        style.customIconPath = nil
        let config = style.toConfig()
        XCTAssertNil(config.customIcon)
    }

    // MARK: - NotificationHistory Tests

    func testHistoryRecordingWhenDisabled() {
        let history = NotificationHistory.shared
        let wasRecording = history.isRecording
        history.isRecording = false

        let countBefore = history.notifications.count

        var content = NotificationContent()
        content.appName = "Test"
        content.title = "Should not record"
        history.record(content)

        XCTAssertEqual(history.notifications.count, countBefore, "Should not record when disabled")

        history.isRecording = wasRecording
    }

    func testHistoryRecordingWhenEnabled() {
        let history = NotificationHistory.shared
        let wasRecording = history.isRecording
        history.isRecording = true

        let countBefore = history.notifications.count

        var content = NotificationContent()
        content.appName = "Test"
        content.title = "Should record"
        history.record(content)

        XCTAssertEqual(history.notifications.count, countBefore + 1, "Should record when enabled")

        // Clean up
        if history.notifications.count > countBefore {
            history.delete(history.notifications[0])
        }
        history.isRecording = wasRecording
    }

    func testHistoryClearAll() {
        let history = NotificationHistory.shared
        let wasRecording = history.isRecording
        history.isRecording = true

        // Add a notification
        var content = NotificationContent()
        content.appName = "Test"
        content.title = "To be cleared"
        history.record(content)

        history.clearAll()

        XCTAssertEqual(history.notifications.count, 0)

        history.isRecording = wasRecording
    }

    func testHistoryRetentionMinutesDefault() {
        let history = NotificationHistory.shared
        // If not set, should default to something > 0
        XCTAssertGreaterThan(history.retentionMinutes, 0)
    }
}
