import CoreGraphics

public enum QuotaPanelFrameConstraint {
    public static func constrained(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let x = constrainedOrigin(
            frameMin: frame.minX,
            frameLength: frame.width,
            visibleMin: visibleFrame.minX,
            visibleLength: visibleFrame.width
        )
        let y = constrainedOrigin(
            frameMin: frame.minY,
            frameLength: frame.height,
            visibleMin: visibleFrame.minY,
            visibleLength: visibleFrame.height
        )
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }

    private static func constrainedOrigin(
        frameMin: CGFloat,
        frameLength: CGFloat,
        visibleMin: CGFloat,
        visibleLength: CGFloat
    ) -> CGFloat {
        guard frameLength <= visibleLength else {
            return visibleMin
        }

        let maxOrigin = visibleMin + visibleLength - frameLength
        return min(max(frameMin, visibleMin), maxOrigin)
    }
}
