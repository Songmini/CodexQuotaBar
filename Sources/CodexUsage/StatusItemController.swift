import AppKit
import CodexUsageCore

@MainActor
final class StatusItemController: NSObject {
    private let quotaController: QuotaController
    private let floatingPanelController: FloatingPanelController
    private var statusItem: NSStatusItem?
    private var currentResult: QuotaReadResult = .idle

    init(
        quotaController: QuotaController,
        floatingPanelController: FloatingPanelController
    ) {
        self.quotaController = quotaController
        self.floatingPanelController = floatingPanelController
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.title = QuotaStatusFormatter.menuBarIconText(for: currentResult)
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            button.image = StatusIconRenderer.image(for: currentResult, appearance: button.effectiveAppearance)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemAction(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Codex Usage"
        }

        quotaController.onChange = { [weak self] result in
            self?.apply(result)
        }
    }

    func tearDown() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func apply(_ result: QuotaReadResult) {
        currentResult = result
        statusItem?.button?.title = QuotaStatusFormatter.menuBarIconText(for: result)
        statusItem?.button?.image = iconImage(for: result)
        statusItem?.button?.imagePosition = .imageOnly
        statusItem?.button?.toolTip = toolTip(for: result)
        floatingPanelController.update(result)
    }

    private func iconImage(for result: QuotaReadResult) -> NSImage {
        StatusIconRenderer.image(for: result, appearance: statusItem?.button?.effectiveAppearance)
    }

    private func toolTip(for result: QuotaReadResult) -> String {
        switch result {
        case .idle:
            return "Codex Usage has not been read yet"
        case .notApplicable:
            return "Codex Usage is only available for ChatGPT plans"
        case .success(let snapshot):
            return "1-week \(snapshot.weekly.remainingPercent)% remaining"
        case .failure(let error, let lastSnapshot):
            if let lastSnapshot {
                return "\(error.message). Last 1-week value: \(lastSnapshot.weekly.remainingPercent)%"
            }
            return error.message
        }
    }

    @objc private func statusItemAction(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePanelAndRefresh()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            showMenu()
        } else {
            togglePanelAndRefresh()
        }
    }

    private func togglePanelAndRefresh() {
        let didShow = floatingPanelController.toggle(result: currentResult, near: statusItem?.button?.window)
        if didShow {
            quotaController.refresh()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        if floatingPanelController.isVisible {
            menu.addItem(menuItem("Hide Floating Panel", action: #selector(hidePanel)))
        } else {
            menu.addItem(menuItem("Show Floating Panel", action: #selector(showPanel)))
        }

        menu.addItem(menuItem("Refresh Usage", action: #selector(refresh)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Activate Codex", action: #selector(activateCodex)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit", action: #selector(quit)))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showPanel() {
        floatingPanelController.show(result: currentResult, near: statusItem?.button?.window)
    }

    @objc private func hidePanel() {
        floatingPanelController.hide()
    }

    @objc private func refresh() {
        quotaController.refresh()
    }

    @objc private func activateCodex() {
        quotaController.activateCodex()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
