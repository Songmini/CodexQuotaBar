import XCTest
import CoreGraphics
@testable import CodexUsageCore

final class CodexQuotaParserTests: XCTestCase {
    func testDecodesCodexAppServerRateLimitResponse() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": {
              "usedPercent": 27,
              "windowDurationMins": 300,
              "resetsAt": 1778664354
            },
            "secondary": {
              "usedPercent": 14,
              "windowDurationMins": 10080,
              "resetsAt": 1779201534
            },
            "credits": {
              "hasCredits": false,
              "unlimited": false,
              "balance": "0"
            },
            "planType": "pro",
            "rateLimitReachedType": null
          }
        }
        """

        let snapshot = try CodexAppServerQuotaDecoder.decodeSnapshot(
            from: Data(json.utf8),
            readAt: Date(timeIntervalSince1970: 1_778_657_934)
        )

        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 73)
        XCTAssertEqual(snapshot.fiveHour.detailText, "resets in 1h 47m")
        XCTAssertEqual(snapshot.weekly.remainingPercent, 86)
        XCTAssertEqual(snapshot.weekly.detailText, "resets in 6d 7h")
    }

    func testDecodesCodexAppServerJSONRPCEnvelope() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "primary": {
                "usedPercent": 40,
                "windowDurationMins": 300,
                "resetsAt": null
              },
              "secondary": {
                "usedPercent": 10,
                "windowDurationMins": 10080,
                "resetsAt": null
              }
            }
          }
        }
        """

        let snapshot = try CodexAppServerQuotaDecoder.decodeSnapshot(from: Data(json.utf8))

        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 60)
        XCTAssertEqual(snapshot.fiveHour.detailText, "300m window")
        XCTAssertEqual(snapshot.weekly.remainingPercent, 90)
        XCTAssertEqual(snapshot.weekly.detailText, "10080m window")
    }

    func testDecodeOutcomeReturnsNotApplicableForApiOnlyUser() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": null,
            "secondary": null
          }
        }
        """

        let outcome = try CodexAppServerQuotaDecoder.decodeOutcome(from: Data(json.utf8))

        XCTAssertEqual(outcome, .notApplicable)
    }

    func testStatusTitleIsEmptyForNotApplicable() {
        XCTAssertEqual(QuotaStatusFormatter.menuBarTitle(for: .notApplicable), "")
    }

    func testCompactPanelRowsAreEmptyForNotApplicable() {
        XCTAssertEqual(QuotaCompactPanelFormatter.rows(for: .notApplicable), [])
    }

    func testParsesKoreanFiveHourAndWeeklyQuota() {
        let snapshot = CodexQuotaParser.parse(fragments: [
            "남은 요금 한도",
            "5시간",
            "72%",
            "3시간 12분 남음",
            "1주",
            "48%",
            "4일 2시간 남음"
        ])

        XCTAssertEqual(snapshot?.fiveHour.remainingPercent, 72)
        XCTAssertEqual(snapshot?.fiveHour.detailText, "3시간 12분 남음")
        XCTAssertEqual(snapshot?.weekly.remainingPercent, 48)
        XCTAssertEqual(snapshot?.weekly.detailText, "4일 2시간 남음")
    }

    func testParsesEnglishFiveHourAndWeeklyQuota() {
        let snapshot = CodexQuotaParser.parse(fragments: [
            "Usage",
            "5-hour limit",
            "64% remaining",
            "resets in 1h 20m",
            "1-week limit",
            "87% remaining",
            "6d 4h left"
        ])

        XCTAssertEqual(snapshot?.fiveHour.remainingPercent, 64)
        XCTAssertEqual(snapshot?.fiveHour.detailText, "resets in 1h 20m")
        XCTAssertEqual(snapshot?.weekly.remainingPercent, 87)
        XCTAssertEqual(snapshot?.weekly.detailText, "6d 4h left")
    }

    func testReturnsNilWhenQuotaLabelsAreMissing() {
        let snapshot = CodexQuotaParser.parse(fragments: [
            "Settings",
            "General",
            "Account"
        ])

        XCTAssertNil(snapshot)
    }

    func testClampsPercentagesToValidRange() {
        let snapshot = CodexQuotaParser.parse(fragments: [
            "5h",
            "129%",
            "1 week",
            "-8%"
        ])

        XCTAssertEqual(snapshot?.fiveHour.remainingPercent, 100)
        XCTAssertEqual(snapshot?.weekly.remainingPercent, 0)
    }

    func testStatusTitleUsesWeeklyRemainingPercent() {
        let snapshot = QuotaSnapshot(
            fiveHour: QuotaLimitReading(kind: .fiveHour, remainingPercent: 72, detailText: "3h left"),
            weekly: QuotaLimitReading(kind: .weekly, remainingPercent: 48, detailText: "4d left"),
            readAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(QuotaStatusFormatter.menuBarTitle(for: .success(snapshot)), "1w 48%")
    }

    func testStatusIconUsesNoText() {
        let snapshot = QuotaSnapshot(
            fiveHour: QuotaLimitReading(kind: .fiveHour, remainingPercent: 72, detailText: "3h left"),
            weekly: QuotaLimitReading(kind: .weekly, remainingPercent: 48, detailText: "4d left"),
            readAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(QuotaStatusFormatter.menuBarIconText(for: .success(snapshot)), "")
        XCTAssertEqual(QuotaStatusFormatter.menuBarIconText(for: .idle), "")
        XCTAssertEqual(QuotaStatusFormatter.menuBarIconText(for: .failure(.quotaNotFound, lastSnapshot: nil)), "")
    }

    func testGaugeFillUsesWeeklyRemainingPercent() {
        XCTAssertEqual(QuotaGaugeFormatter.fillPercent(forWeeklyRemainingPercent: 86), 86)
        XCTAssertEqual(QuotaGaugeFormatter.fillPercent(forWeeklyRemainingPercent: 0), 0)
        XCTAssertEqual(QuotaGaugeFormatter.fillPercent(forWeeklyRemainingPercent: 100), 100)
        XCTAssertEqual(QuotaGaugeFormatter.fillPercent(forWeeklyRemainingPercent: -12), 0)
        XCTAssertEqual(QuotaGaugeFormatter.fillPercent(forWeeklyRemainingPercent: 124), 100)
    }

    func testCompactPanelRowsUseOneLineLocalizedResetText() {
        let timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let resetAt = calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 15,
            minute: 26
        ))!
        let snapshot = QuotaSnapshot(
            fiveHour: QuotaLimitReading(
                kind: .fiveHour,
                remainingPercent: 72,
                detailText: "resets in 3h",
                resetAt: resetAt
            ),
            weekly: QuotaLimitReading(
                kind: .weekly,
                remainingPercent: 48,
                detailText: "resets in 4d",
                resetAt: resetAt
            ),
            readAt: Date(timeIntervalSince1970: 0)
        )

        let rows = QuotaCompactPanelFormatter.rows(
            for: .success(snapshot),
            locale: Locale(identifier: "en_US"),
            timeZone: timeZone
        )

        XCTAssertEqual(rows.map(\.title), ["5-hour", "1-week"])
        XCTAssertEqual(rows.map(\.percentText), ["72%", "48%"])
        XCTAssertEqual(rows.map(\.resetText), ["PM 3:26", "May 13"])
        XCTAssertEqual(rows.map(\.progressPercent), [72, 48])

        let koreanRows = QuotaCompactPanelFormatter.rows(
            for: .success(snapshot),
            locale: Locale(identifier: "ko_KR"),
            timeZone: timeZone
        )

        XCTAssertEqual(koreanRows.map(\.resetText), ["오후 3:26", "5월 13일"])
    }

    func testPanelModeTogglesBetweenFullAndCompact() {
        XCTAssertEqual(QuotaPanelMode.full.toggled, .compact)
        XCTAssertEqual(QuotaPanelMode.compact.toggled, .full)
    }

    func testPanelFrameIsConstrainedToVisibleScreenFrame() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1000, height: 700)

        XCTAssertEqual(
            QuotaPanelFrameConstraint.constrained(
                CGRect(x: 40, y: 20, width: 300, height: 200),
                to: visibleFrame
            ),
            CGRect(x: 100, y: 50, width: 300, height: 200)
        )

        XCTAssertEqual(
            QuotaPanelFrameConstraint.constrained(
                CGRect(x: 960, y: 620, width: 300, height: 200),
                to: visibleFrame
            ),
            CGRect(x: 800, y: 550, width: 300, height: 200)
        )
    }

    func testStatusTitleUsesPlaceholderBeforeFirstRead() {
        XCTAssertEqual(QuotaStatusFormatter.menuBarTitle(for: .idle), "1w --")
    }

    func testStatusTitleUsesWarningWhenFailureHasNoLastSnapshot() {
        XCTAssertEqual(
            QuotaStatusFormatter.menuBarTitle(for: .failure(.quotaNotFound, lastSnapshot: nil)),
            "1w !"
        )
    }

    func testStatusTitleKeepsLastWeeklyValueAfterFailure() {
        let snapshot = QuotaSnapshot(
            fiveHour: QuotaLimitReading(kind: .fiveHour, remainingPercent: 31, detailText: "1h left"),
            weekly: QuotaLimitReading(kind: .weekly, remainingPercent: 44, detailText: "2d left"),
            readAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(
            QuotaStatusFormatter.menuBarTitle(for: .failure(.codexNotRunning, lastSnapshot: snapshot)),
            "1w 44%"
        )
    }
}
