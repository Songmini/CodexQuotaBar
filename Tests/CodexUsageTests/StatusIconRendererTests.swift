import AppKit
import XCTest
@testable import CodexUsage

@MainActor
final class StatusIconRendererTests: XCTestCase {
    func testPrimaryColorFollowsMenuBarAppearance() throws {
        let darkColor = try XCTUnwrap(StatusIconRenderer.primaryColor(
            for: NSAppearance(named: .darkAqua)
        ).usingColorSpace(.deviceRGB))
        let lightColor = try XCTUnwrap(StatusIconRenderer.primaryColor(
            for: NSAppearance(named: .aqua)
        ).usingColorSpace(.deviceRGB))

        XCTAssertGreaterThan(darkColor.redComponent, 0.90)
        XCTAssertGreaterThan(darkColor.greenComponent, 0.90)
        XCTAssertGreaterThan(darkColor.blueComponent, 0.90)

        XCTAssertLessThan(lightColor.redComponent, 0.20)
        XCTAssertLessThan(lightColor.greenComponent, 0.20)
        XCTAssertLessThan(lightColor.blueComponent, 0.20)
    }
}
