#!/usr/bin/env swift

import AppKit
import Foundation

struct IconSpec {
    let filename: String
    let pixels: Int
    let points: CGFloat
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let appIconWeeklyRemainingPercent = 80
let gaugeStartAngle: CGFloat = 90
let gaugeSweepAngle: CGFloat = 258

let specs = [
    IconSpec(filename: "icon_16x16.png", pixels: 16, points: 16),
    IconSpec(filename: "icon_16x16@2x.png", pixels: 32, points: 16),
    IconSpec(filename: "icon_32x32.png", pixels: 32, points: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64, points: 32),
    IconSpec(filename: "icon_128x128.png", pixels: 128, points: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256, points: 128),
    IconSpec(filename: "icon_256x256.png", pixels: 256, points: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512, points: 256),
    IconSpec(filename: "icon_512x512.png", pixels: 512, points: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024, points: 512)
]

for spec in specs {
    let image = NSImage(size: NSSize(width: spec.points, height: spec.points))
    image.lockFocus()
    drawAppIcon(in: NSRect(x: 0, y: 0, width: spec.points, height: spec.points))
    image.unlockFocus()

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: spec.pixels,
        pixelsHigh: spec.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap for \(spec.filename)")
    }

    bitmap.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(spec.filename)")
    }

    try png.write(to: outputURL.appendingPathComponent(spec.filename))
}

private func drawAppIcon(in rect: NSRect) {
    let scale = rect.width / 1024
    let baseRect = rect.insetBy(dx: 76 * scale, dy: 76 * scale)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 165 * scale, yRadius: 165 * scale)

    NSColor.clear.setFill()
    rect.fill()

    NSColor(calibratedWhite: 0, alpha: 0.28).setFill()
    NSBezierPath(roundedRect: baseRect.offsetBy(dx: 0, dy: -16 * scale), xRadius: 165 * scale, yRadius: 165 * scale).fill()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.23, green: 0.27, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.08, alpha: 1)
    ])?.draw(in: basePath, angle: 92)

    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    basePath.lineWidth = 7 * scale
    basePath.stroke()

    let center = NSPoint(x: rect.midX, y: rect.midY + 8 * scale)
    let outerRadius = 338 * scale
    let innerRadius = 222 * scale

    NSColor(calibratedWhite: 0, alpha: 0.45).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: center.x - outerRadius,
        y: center.y - outerRadius,
        width: outerRadius * 2,
        height: outerRadius * 2
    )).fill()

    NSColor(calibratedWhite: 1, alpha: 0.15).setStroke()
    circle(center: center, radius: outerRadius).stroke()
    circle(center: center, radius: innerRadius).stroke()

    drawWeeklyRemainingArc(
        center: center,
        radius: outerRadius - 37 * scale,
        width: 68 * scale,
        weeklyRemainingPercent: appIconWeeklyRemainingPercent,
        color: accent
    )

    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.13, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: center.x - innerRadius,
        y: center.y - innerRadius,
        width: innerRadius * 2,
        height: innerRadius * 2
    )).fill()

    drawCodeMark(in: NSRect(
        x: center.x - 244 * scale,
        y: center.y - 124 * scale,
        width: 488 * scale,
        height: 220 * scale
    ), scale: scale)
}

private var accent: NSColor {
    NSColor(calibratedRed: 0.10, green: 0.88, blue: 0.84, alpha: 1)
}

private func circle(center: NSPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath(ovalIn: NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    path.lineWidth = 4
    return path
}

private func drawArc(center: NSPoint, radius: CGFloat, start: CGFloat, end: CGFloat, width: CGFloat, color: NSColor) {
    color.setStroke()
    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
    arc.lineWidth = width
    arc.lineCapStyle = .butt
    arc.stroke()
}

private func drawWeeklyRemainingArc(center: NSPoint, radius: CGFloat, width: CGFloat, weeklyRemainingPercent: Int, color: NSColor) {
    let fillPercent = min(max(weeklyRemainingPercent, 0), 100)
    guard fillPercent > 0 else {
        return
    }

    let endAngle = gaugeStartAngle - gaugeSweepAngle * CGFloat(fillPercent) / 100
    drawArc(center: center, radius: radius, start: gaugeStartAngle, end: endAngle, width: width, color: color)
}

private func drawCodeMark(in rect: NSRect, scale: CGFloat) {
    let strokeWidth = 42 * scale

    let left = NSBezierPath()
    left.move(to: NSPoint(x: rect.minX + 134 * scale, y: rect.minY + 16 * scale))
    left.line(to: NSPoint(x: rect.minX + 24 * scale, y: rect.midY))
    left.line(to: NSPoint(x: rect.minX + 134 * scale, y: rect.maxY - 16 * scale))
    left.lineWidth = strokeWidth
    left.lineCapStyle = .round
    left.lineJoinStyle = .round
    NSColor.white.setStroke()
    left.stroke()

    let right = NSBezierPath()
    right.move(to: NSPoint(x: rect.maxX - 134 * scale, y: rect.minY + 16 * scale))
    right.line(to: NSPoint(x: rect.maxX - 24 * scale, y: rect.midY))
    right.line(to: NSPoint(x: rect.maxX - 134 * scale, y: rect.maxY - 16 * scale))
    right.lineWidth = strokeWidth
    right.lineCapStyle = .round
    right.lineJoinStyle = .round
    NSColor.white.setStroke()
    right.stroke()

    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: rect.midX, y: rect.minY + 12 * scale))
    divider.line(to: NSPoint(x: rect.midX, y: rect.maxY - 12 * scale))
    divider.lineWidth = 34 * scale
    divider.lineCapStyle = .round
    NSColor.white.setStroke()
    divider.stroke()

    let prompt = NSBezierPath()
    prompt.move(to: NSPoint(x: rect.minX + 148 * scale, y: rect.minY - 104 * scale))
    prompt.line(to: NSPoint(x: rect.minX + 208 * scale, y: rect.minY - 154 * scale))
    prompt.line(to: NSPoint(x: rect.minX + 148 * scale, y: rect.minY - 204 * scale))
    prompt.lineWidth = 28 * scale
    prompt.lineCapStyle = .round
    prompt.lineJoinStyle = .round
    accent.setStroke()
    prompt.stroke()

    let underscore = NSBezierPath()
    underscore.move(to: NSPoint(x: rect.midX + 40 * scale, y: rect.minY - 202 * scale))
    underscore.line(to: NSPoint(x: rect.midX + 128 * scale, y: rect.minY - 202 * scale))
    underscore.lineWidth = 18 * scale
    underscore.lineCapStyle = .round
    NSColor(calibratedWhite: 0.72, alpha: 1).setStroke()
    underscore.stroke()
}
