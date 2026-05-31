import Foundation

public enum QuotaWindowKind: Equatable {
    case fiveHour
    case weekly

    public var displayTitle: String {
        switch self {
        case .fiveHour:
            return "5-hour"
        case .weekly:
            return "1-week"
        }
    }
}

public struct QuotaLimitReading: Equatable {
    public let kind: QuotaWindowKind
    public let remainingPercent: Int
    public let detailText: String?
    public let resetAt: Date?

    public init(kind: QuotaWindowKind, remainingPercent: Int, detailText: String?, resetAt: Date? = nil) {
        self.kind = kind
        self.remainingPercent = min(max(remainingPercent, 0), 100)
        self.detailText = detailText
        self.resetAt = resetAt
    }
}

public struct QuotaSnapshot: Equatable {
    public let fiveHour: QuotaLimitReading
    public let weekly: QuotaLimitReading
    public let readAt: Date

    public init(fiveHour: QuotaLimitReading, weekly: QuotaLimitReading, readAt: Date = Date()) {
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.readAt = readAt
    }
}

public enum QuotaReadError: Error, Equatable {
    case codexNotRunning
    case codexCommandUnavailable
    case codexSignatureInvalid
    case appServerUnavailable
    case quotaNotFound

    public var message: String {
        switch self {
        case .codexNotRunning:
            return "Codex is not running"
        case .codexCommandUnavailable:
            return "Codex app command not found"
        case .codexSignatureInvalid:
            return "Codex app signature could not be verified"
        case .appServerUnavailable:
            return "Codex app-server request failed"
        case .quotaNotFound:
            return "Codex Usage was not returned"
        }
    }
}

public enum QuotaReadResult: Equatable {
    case idle
    case success(QuotaSnapshot)
    case notApplicable
    case failure(QuotaReadError, lastSnapshot: QuotaSnapshot?)

    public var snapshotForDisplay: QuotaSnapshot? {
        switch self {
        case .idle, .notApplicable:
            return nil
        case .success(let snapshot):
            return snapshot
        case .failure(_, let lastSnapshot):
            return lastSnapshot
        }
    }
}

public enum QuotaPanelMode: Equatable {
    case full
    case compact

    public var toggled: QuotaPanelMode {
        switch self {
        case .full:
            return .compact
        case .compact:
            return .full
        }
    }
}

public enum QuotaStatusFormatter {
    public static func menuBarTitle(for result: QuotaReadResult) -> String {
        switch result {
        case .idle:
            return "1w --"
        case .notApplicable:
            return ""
        case .success(let snapshot):
            return weeklyTitle(snapshot)
        case .failure(_, let lastSnapshot):
            guard let lastSnapshot else {
                return "1w !"
            }
            return weeklyTitle(lastSnapshot)
        }
    }

    public static func menuBarIconText(for result: QuotaReadResult) -> String {
        ""
    }

    private static func weeklyTitle(_ snapshot: QuotaSnapshot) -> String {
        "1w \(snapshot.weekly.remainingPercent)%"
    }
}

public enum QuotaGaugeFormatter {
    public static func fillPercent(forWeeklyRemainingPercent remainingPercent: Int) -> Int {
        min(max(remainingPercent, 0), 100)
    }
}

public struct QuotaCompactPanelRow: Equatable {
    public let title: String
    public let percentText: String
    public let resetText: String
    public let progressPercent: Int
}

public enum QuotaCompactPanelFormatter {
    public static func rows(
        for result: QuotaReadResult,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> [QuotaCompactPanelRow] {
        if case .notApplicable = result {
            return []
        }

        guard let snapshot = result.snapshotForDisplay else {
            return [
                QuotaCompactPanelRow(
                    title: QuotaWindowKind.fiveHour.displayTitle,
                    percentText: "--",
                    resetText: "--",
                    progressPercent: 0
                ),
                QuotaCompactPanelRow(
                    title: QuotaWindowKind.weekly.displayTitle,
                    percentText: "--",
                    resetText: "--",
                    progressPercent: 0
                )
            ]
        }

        return [snapshot.fiveHour, snapshot.weekly].map { reading in
            let resetText = formattedResetText(
                for: reading.resetAt,
                kind: reading.kind,
                locale: locale,
                timeZone: timeZone
            )
            return QuotaCompactPanelRow(
                title: reading.kind.displayTitle,
                percentText: "\(reading.remainingPercent)%",
                resetText: resetText,
                progressPercent: reading.remainingPercent
            )
        }
    }

    private static func formattedResetText(
        for resetAt: Date?,
        kind: QuotaWindowKind,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        guard let resetAt else {
            return "--"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        switch kind {
        case .fiveHour:
            formatter.dateFormat = "a h:mm"
        case .weekly:
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        }

        return formatter.string(from: resetAt)
    }
}
