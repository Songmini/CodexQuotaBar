import AppKit

final class FloatingQuotaPanel: NSPanel {
    var onMouseUp: (() -> Void)?
    private(set) var isMouseTrackingDrag = false

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            isMouseTrackingDrag = true
        }

        super.sendEvent(event)

        if event.type == .leftMouseUp {
            isMouseTrackingDrag = false
            onMouseUp?()
        }
    }
}
