import Foundation

public enum CodexQuotaParser {
    public static func parse(fragments: [String], readAt: Date = Date()) -> QuotaSnapshot? {
        let lines = fragments
            .map { normalized($0) }
            .filter { !$0.isEmpty }

        guard let fiveHour = parseLimit(kind: .fiveHour, lines: lines),
              let weekly = parseLimit(kind: .weekly, lines: lines) else {
            return nil
        }

        return QuotaSnapshot(fiveHour: fiveHour, weekly: weekly, readAt: readAt)
    }

    private static func parseLimit(kind: QuotaWindowKind, lines: [String]) -> QuotaLimitReading? {
        guard let startIndex = lines.indices.first(where: { line(lines[$0], matchesAny: anchors(for: kind)) }) else {
            return nil
        }

        let otherKind: QuotaWindowKind = kind == .fiveHour ? .weekly : .fiveHour
        let nextOtherIndex = lines.indices
            .filter { $0 > startIndex }
            .first(where: { line(lines[$0], matchesAny: anchors(for: otherKind)) })
        let endIndex = min(nextOtherIndex ?? lines.endIndex, startIndex + 8)
        let section = Array(lines[startIndex..<endIndex])
        let sectionText = section.joined(separator: " ")

        guard let percent = firstPercent(in: sectionText) else {
            return nil
        }

        return QuotaLimitReading(
            kind: kind,
            remainingPercent: percent,
            detailText: firstDetailText(in: Array(section.dropFirst()))
        )
    }

    private static func anchors(for kind: QuotaWindowKind) -> [String] {
        switch kind {
        case .fiveHour:
            return ["5시간", "5-hour", "5 hour", "5h"]
        case .weekly:
            return ["1주", "1-week", "1 week", "weekly", "week"]
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func line(_ line: String, matchesAny anchors: [String]) -> Bool {
        let lowercased = line.lowercased()
        return anchors.contains { lowercased.contains($0.lowercased()) }
    }

    private static func firstPercent(in text: String) -> Int? {
        let pattern = #"(-?\d+(?:\.\d+)?)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text),
              let value = Double(text[range]) else {
            return nil
        }

        return min(max(Int(value.rounded()), 0), 100)
    }

    private static func firstDetailText(in lines: [String]) -> String? {
        for line in lines {
            if line.contains("%") {
                continue
            }
            if containsDetailMarker(line) || containsTimeToken(line) {
                return line
            }
        }
        return nil
    }

    private static func containsDetailMarker(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return ["남음", "remaining", "resets", "reset", "left"].contains {
            lowercased.contains($0)
        }
    }

    private static func containsTimeToken(_ line: String) -> Bool {
        let pattern = #"\d+\s*(시간|분|일|주|h|m|d|day|days|hour|hours|minute|minutes)"#
        return line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
