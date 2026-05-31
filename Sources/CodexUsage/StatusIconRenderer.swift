import AppKit
import CodexUsageCore

@MainActor
enum StatusIconRenderer {
    static func image(for result: QuotaReadResult, appearance: NSAppearance? = nil) -> NSImage {
        let image = NSImage(size: iconSize)

        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: iconSize)
        let primary = primaryColor(for: appearance)

        if case .notApplicable = result {
            drawCodeOnlyMark(in: bounds.insetBy(dx: 2, dy: 1), primaryColor: primary)
        } else {
            drawGaugeMark(
                in: bounds.insetBy(dx: 2, dy: 1),
                primaryColor: primary,
                weeklyRemainingPercent: result.snapshotForDisplay?.weekly.remainingPercent
            )
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func primaryColor(for appearance: NSAppearance?) -> NSColor {
        let darkMatches: [NSAppearance.Name] = [.darkAqua, .vibrantDark]
        let allMatches: [NSAppearance.Name] = darkMatches + [.aqua, .vibrantLight]
        let match = appearance?.bestMatch(from: allMatches)

        if let match, darkMatches.contains(match) {
            return NSColor(calibratedWhite: 0.96, alpha: 1)
        }
        return NSColor(calibratedWhite: 0.08, alpha: 1)
    }

    static func drawGaugeMark(in rect: NSRect, primaryColor: NSColor, weeklyRemainingPercent: Int?) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.40
        let accentColor = accentColor(forWeeklyRemainingPercent: weeklyRemainingPercent)
        let startAngle: CGFloat = 90
        let sweepAngle: CGFloat = 258

        primaryColor.withAlphaComponent(0.70).setStroke()
        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: startAngle - sweepAngle,
            clockwise: true
        )
        track.lineWidth = max(2.4, rect.height * 0.13)
        track.lineCapStyle = .round
        track.stroke()

        if let fillPercent = weeklyFillPercent(fromRemainingPercent: weeklyRemainingPercent), fillPercent > 0 {
            accentColor.setStroke()
            let progress = NSBezierPath()
            let endAngle = startAngle - sweepAngle * CGFloat(fillPercent) / 100
            progress.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            progress.lineWidth = track.lineWidth
            progress.lineCapStyle = .round
            progress.stroke()
        }

        drawCodeMark(in: NSRect(
            x: center.x - radius * 0.58,
            y: center.y - radius * 0.48,
            width: radius * 1.16,
            height: radius * 0.96
        ), primaryColor: primaryColor)
    }

    static var iconSize: NSSize {
        NSSize(width: 26, height: 22)
    }

    static func drawCodeOnlyMark(in rect: NSRect, primaryColor: NSColor) {
        let size = min(rect.width, rect.height) * 0.86
        let markRect = NSRect(
            x: rect.midX - size / 2,
            y: rect.midY - size / 2,
            width: size,
            height: size
        )
        drawCodeMark(in: markRect, primaryColor: primaryColor)
    }

    static func accentColor(forWeeklyRemainingPercent remainingPercent: Int?) -> NSColor {
        guard let remainingPercent else {
            return NSColor(calibratedRed: 0.10, green: 0.86, blue: 0.82, alpha: 1)
        }

        if remainingPercent < 20 {
            return NSColor(calibratedRed: 0.95, green: 0.28, blue: 0.28, alpha: 1)
        }
        if remainingPercent < 50 {
            return NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.25, alpha: 1)
        }
        return NSColor(calibratedRed: 0.10, green: 0.86, blue: 0.82, alpha: 1)
    }

    private static func weeklyFillPercent(fromRemainingPercent remainingPercent: Int?) -> Int? {
        guard let remainingPercent else {
            return nil
        }
        return QuotaGaugeFormatter.fillPercent(forWeeklyRemainingPercent: remainingPercent)
    }

    private static func drawCodeMark(in rect: NSRect, primaryColor: NSColor) {
        let strokeWidth = max(1.6, rect.height * 0.18)
        let insetY = rect.height * 0.12
        let left = NSBezierPath()
        left.move(to: NSPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + insetY))
        left.line(to: NSPoint(x: rect.minX + rect.width * 0.06, y: rect.midY))
        left.line(to: NSPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY - insetY))
        left.lineWidth = strokeWidth
        left.lineCapStyle = .round
        left.lineJoinStyle = .round
        primaryColor.setStroke()
        left.stroke()

        let right = NSBezierPath()
        right.move(to: NSPoint(x: rect.maxX - rect.width * 0.30, y: rect.minY + insetY))
        right.line(to: NSPoint(x: rect.maxX - rect.width * 0.06, y: rect.midY))
        right.line(to: NSPoint(x: rect.maxX - rect.width * 0.30, y: rect.maxY - insetY))
        right.lineWidth = strokeWidth
        right.lineCapStyle = .round
        right.lineJoinStyle = .round
        primaryColor.setStroke()
        right.stroke()

        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.18))
        divider.line(to: NSPoint(x: rect.midX, y: rect.maxY - rect.height * 0.18))
        divider.lineWidth = strokeWidth
        divider.lineCapStyle = .round
        primaryColor.setStroke()
        divider.stroke()
    }
}
