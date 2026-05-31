import AppKit
import CodexUsageCore

@MainActor
final class FloatingPanelController {
    private let frameAutosaveKey = "CodexUsage.panelFrame"
    private let fullPanelSize = NSSize(width: 390, height: 214)
    private let compactPanelSize = NSSize(width: 238, height: 96)
    private var panel: NSPanel?
    private var fullPanelView: QuotaPanelView?
    private var compactPanelView: CompactQuotaPanelView?
    private var currentResult: QuotaReadResult = .idle
    private var mode: QuotaPanelMode = .full
    private var settleTask: Task<Void, Never>?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(result: QuotaReadResult, near sourceWindow: NSWindow?) {
        currentResult = result
        let panel = panel ?? makePanel(near: sourceWindow)
        self.panel = panel
        installContentView(in: panel, mode: mode)
        update(result)
        panel.orderFrontRegardless()
    }

    func toggle(result: QuotaReadResult, near sourceWindow: NSWindow?) -> Bool {
        if isVisible {
            hide()
            return false
        }

        show(result: result, near: sourceWindow)
        return true
    }

    func update(_ result: QuotaReadResult) {
        currentResult = result
        fullPanelView?.update(result)
        compactPanelView?.update(result)
    }

    func hide() {
        settleTask?.cancel()
        saveFrame()
        panel?.orderOut(nil)
    }

    private func makePanel(near sourceWindow: NSWindow?) -> NSPanel {
        let screen = sourceWindow?.screen ?? NSScreen.main
        let frame = constrainedFrame(
            savedFrame(for: panelSize(for: mode)) ?? defaultFrame(near: sourceWindow, size: panelSize(for: mode)),
            on: screen
        )
        let panel = FloatingQuotaPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.onMouseUp = { [weak self] in
            Task { @MainActor in
                self?.settlePanelInsideScreenIfNeeded()
            }
        }

        installContentView(in: panel, mode: mode)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePanelMove()
            }
        }

        return panel
    }

    private func installContentView(in panel: NSPanel, mode: QuotaPanelMode) {
        let size = panelSize(for: mode)
        fullPanelView = nil
        compactPanelView = nil

        switch mode {
        case .full:
            let view = QuotaPanelView(frame: NSRect(origin: .zero, size: size))
            view.onModeToggle = { [weak self] in
                self?.toggleMode()
            }
            view.autoresizingMask = [.width, .height]
            panel.contentView = view
            fullPanelView = view
        case .compact:
            let view = CompactQuotaPanelView(frame: NSRect(origin: .zero, size: size))
            view.onModeToggle = { [weak self] in
                self?.toggleMode()
            }
            view.autoresizingMask = [.width, .height]
            panel.contentView = view
            compactPanelView = view
        }
    }

    private func toggleMode() {
        guard let panel else {
            return
        }

        mode = mode.toggled
        panel.contentView = nil
        fullPanelView = nil
        compactPanelView = nil
        resize(panel, to: panelSize(for: mode))
        installContentView(in: panel, mode: mode)
        update(currentResult)
        saveFrame()
    }

    private func resize(_ panel: NSPanel, to size: NSSize) {
        let frame = panel.frame
        let origin = NSPoint(x: frame.minX, y: frame.maxY - size.height)
        let nextFrame = constrainedFrame(NSRect(origin: origin, size: size), on: panel.screen)
        panel.setFrame(nextFrame, display: true, animate: false)
        panel.contentView?.frame = NSRect(origin: .zero, size: size)
    }

    private func panelSize(for mode: QuotaPanelMode) -> NSSize {
        switch mode {
        case .full:
            return fullPanelSize
        case .compact:
            return compactPanelSize
        }
    }

    private func defaultFrame(near sourceWindow: NSWindow?, size: NSSize) -> NSRect {
        let screen = sourceWindow?.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 22,
            y: visibleFrame.maxY - size.height - 28
        )
        return NSRect(origin: origin, size: size)
    }

    private func savedFrame(for size: NSSize) -> NSRect? {
        guard let string = UserDefaults.standard.string(forKey: frameAutosaveKey) else {
            return nil
        }
        let rect = NSRectFromString(string)
        guard rect.width > 0, rect.height > 0 else {
            return nil
        }
        return NSRect(origin: rect.origin, size: size)
    }

    private func constrainedFrame(_ frame: NSRect, on screen: NSScreen?) -> NSRect {
        let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return QuotaPanelFrameConstraint.constrained(frame, to: visibleFrame)
    }

    private func handlePanelMove() {
        guard let panel else {
            return
        }

        if (panel as? FloatingQuotaPanel)?.isMouseTrackingDrag == true {
            return
        }

        saveFrame()
        scheduleSettlePanelInsideScreen()
    }

    private func scheduleSettlePanelInsideScreen() {
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.settlePanelInsideScreenIfNeeded()
        }
    }

    private func settlePanelInsideScreenIfNeeded() {
        settleTask?.cancel()
        guard let panel else {
            return
        }

        let constrained = constrainedFrame(panel.frame, on: panel.screen)
        guard constrained != panel.frame else {
            saveFrame()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(constrained, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.saveFrame()
            }
        }
    }

    private func saveFrame() {
        guard let panel else {
            return
        }
        let frame = constrainedFrame(panel.frame, on: panel.screen)
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: frameAutosaveKey)
    }
}
