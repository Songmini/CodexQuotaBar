import Foundation

public enum CodexAppServerQuotaOutcome: Equatable {
    case snapshot(QuotaSnapshot)
    case notApplicable
}

public enum CodexAppServerQuotaDecoder {
    public static func decodeOutcome(from data: Data, readAt: Date = Date()) throws -> CodexAppServerQuotaOutcome {
        let response = try decodeResponse(from: data)
        let limits = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits

        if limits.primary == nil && limits.secondary == nil {
            return .notApplicable
        }

        guard let primary = limits.primary,
              let secondary = limits.secondary else {
            throw DecodingError.valueNotFound(
                RateLimitWindow.self,
                DecodingError.Context(codingPath: [], debugDescription: "Missing Codex rate limit windows")
            )
        }

        return .snapshot(QuotaSnapshot(
            fiveHour: reading(kind: .fiveHour, window: primary, readAt: readAt),
            weekly: reading(kind: .weekly, window: secondary, readAt: readAt),
            readAt: readAt
        ))
    }

    public static func decodeSnapshot(from data: Data, readAt: Date = Date()) throws -> QuotaSnapshot {
        switch try decodeOutcome(from: data, readAt: readAt) {
        case .snapshot(let snapshot):
            return snapshot
        case .notApplicable:
            throw DecodingError.valueNotFound(
                RateLimitWindow.self,
                DecodingError.Context(codingPath: [], debugDescription: "Missing Codex rate limit windows")
            )
        }
    }

    private static func decodeResponse(from data: Data) throws -> RateLimitsResponse {
        if let response = try? JSONDecoder().decode(RateLimitsResponse.self, from: data) {
            return response
        }
        return try JSONDecoder().decode(JSONRPCResponse.self, from: data).result
    }

    private static func reading(kind: QuotaWindowKind, window: RateLimitWindow, readAt: Date) -> QuotaLimitReading {
        let resetAt = window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        return QuotaLimitReading(
            kind: kind,
            remainingPercent: 100 - window.usedPercent,
            detailText: resetDetailText(for: window, readAt: readAt),
            resetAt: resetAt
        )
    }

    private static func resetDetailText(for window: RateLimitWindow, readAt: Date) -> String? {
        guard let resetsAt = window.resetsAt else {
            return window.windowDurationMins.map { "\($0)m window" }
        }

        let resetDate = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        let seconds = max(0, Int(resetDate.timeIntervalSince(readAt)))
        return "resets in \(durationText(seconds: seconds))"
    }

    private static func durationText(seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }
}

private struct JSONRPCResponse: Decodable {
    let result: RateLimitsResponse
}

private struct RateLimitsResponse: Decodable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
}

private struct RateLimitSnapshot: Decodable {
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int?
}
