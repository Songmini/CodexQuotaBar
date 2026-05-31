import Foundation
import CodexUsageCore

@MainActor
final class QuotaController {
    private let reader: CodexAppServerQuotaReader
    private var refreshTimer: Timer?
    private var isRefreshing = false

    private(set) var result: QuotaReadResult = .idle {
        didSet {
            onChange?(result)
        }
    }

    var onChange: ((QuotaReadResult) -> Void)?

    init() {
        self.reader = CodexAppServerQuotaReader()
    }

    init(reader: CodexAppServerQuotaReader) {
        self.reader = reader
    }

    func start() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        let lastSnapshot = result.snapshotForDisplay
        let task = Task.detached(priority: .utility) { [reader] in
            reader.readSnapshot()
        }

        Task { [weak self] in
            let readResult = await task.value
            guard let self else {
                return
            }

            self.isRefreshing = false
            switch readResult {
            case .success(.snapshot(let snapshot)):
                self.result = .success(snapshot)
            case .success(.notApplicable):
                self.result = .notApplicable
            case .failure(let error):
                self.result = .failure(error, lastSnapshot: lastSnapshot)
            }
        }
    }

    func activateCodex() {
        reader.activateCodex()
    }
}
