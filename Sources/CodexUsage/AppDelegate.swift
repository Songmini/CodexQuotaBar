import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let quotaController = QuotaController()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let floatingPanelController = FloatingPanelController()
        let statusItemController = StatusItemController(
            quotaController: quotaController,
            floatingPanelController: floatingPanelController
        )
        statusItemController.setup()
        self.statusItemController = statusItemController

        quotaController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        quotaController.stop()
        statusItemController?.tearDown()
    }
}

@main
enum CodexUsageMain {
    @MainActor
    private static let delegate = AppDelegate()

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
