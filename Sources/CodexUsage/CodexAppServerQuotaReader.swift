import AppKit
import CodexUsageCore
import Foundation
import Security

final class CodexAppServerQuotaReader: @unchecked Sendable {
    private let candidateBundleIdentifiers = [
        "com.openai.codex",
        "com.openai.Codex"
    ]
    private let fallbackCodexAppPath = "/Applications/Codex.app"
    private let openAITeamIdentifier = "2DC432GLL2"

    func readSnapshot() -> Result<CodexAppServerQuotaOutcome, QuotaReadError> {
        let codexURL: URL
        switch codexExecutableURL() {
        case .success(let url):
            codexURL = url
        case .failure(let error):
            return .failure(error)
        }

        do {
            let response = try requestRateLimits(codexURL: codexURL)
            return .success(try CodexAppServerQuotaDecoder.decodeOutcome(from: response))
        } catch is ProcessTimeoutError {
            return .failure(.appServerUnavailable)
        } catch {
            return .failure(.quotaNotFound)
        }
    }

    func activateCodex() {
        for bundleIdentifier in candidateBundleIdentifiers {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                continue
            }
            guard isTrustedCodexApp(at: url) else {
                continue
            }
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            return
        }
    }

    private func codexExecutableURL() -> Result<URL, QuotaReadError> {
        var foundUntrustedCodex = false

        for appURL in codexAppURLs() {
            guard candidateBundleIdentifiers.contains(Bundle(url: appURL)?.bundleIdentifier ?? "") else {
                continue
            }

            guard isTrustedCodexApp(at: appURL) else {
                foundUntrustedCodex = true
                continue
            }

            let codexURL = appURL.appendingPathComponent("Contents/Resources/codex")
            guard FileManager.default.isExecutableFile(atPath: codexURL.path) else {
                continue
            }

            guard isSignedByOpenAI(codexURL) else {
                foundUntrustedCodex = true
                continue
            }

            return .success(codexURL)
        }

        return .failure(foundUntrustedCodex ? .codexSignatureInvalid : .codexCommandUnavailable)
    }

    private func codexAppURLs() -> [URL] {
        var urls: [URL] = []
        for bundleIdentifier in candidateBundleIdentifiers {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
                  !urls.contains(url) else {
                continue
            }
            urls.append(url)
        }

        let fallbackURL = URL(fileURLWithPath: fallbackCodexAppPath)
        if FileManager.default.fileExists(atPath: fallbackURL.path), !urls.contains(fallbackURL) {
            urls.append(fallbackURL)
        }

        return urls
    }

    private func isTrustedCodexApp(at appURL: URL) -> Bool {
        guard candidateBundleIdentifiers.contains(Bundle(url: appURL)?.bundleIdentifier ?? "") else {
            return false
        }
        return isSignedByOpenAI(appURL)
    }

    private func isSignedByOpenAI(_ url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code) == errSecSuccess,
              let code else {
            return false
        }

        guard SecStaticCodeCheckValidity(code, SecCSFlags(), nil) == errSecSuccess else {
            return false
        }

        var signingInformation: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &signingInformation) == errSecSuccess,
              let information = signingInformation as? [String: Any],
              let teamIdentifier = information[kSecCodeInfoTeamIdentifier as String] as? String else {
            return false
        }

        return teamIdentifier == openAITeamIdentifier
    }

    private func requestRateLimits(codexURL: URL) throws -> Data {
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let output = LineCollector()
        let errors = ErrorCollector()

        process.executableURL = codexURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.environment = safeEnvironment()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            output.append(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            errors.append(handle.availableData)
        }

        try process.run()
        defer {
            cleanup(process: process, stdinPipe: stdinPipe, stdoutPipe: stdoutPipe, stderrPipe: stderrPipe)
        }

        write(
            [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "Codex Usage",
                        "version": "1.0"
                    ],
                    "capabilities": [
                        "experimentalApi": true
                    ]
                ]
            ],
            to: stdinPipe
        )

        _ = try output.waitForLine(id: 1, timeout: 8)

        write(
            [
                "jsonrpc": "2.0",
                "id": 2,
                "method": "account/rateLimits/read",
                "params": NSNull()
            ],
            to: stdinPipe
        )

        let response = try output.waitForLine(id: 2, timeout: 20)

        if response.contains(#""error""#.data(using: .utf8)!) {
            throw AppServerError(message: errors.text())
        }

        return response
    }

    private func write(_ object: [String: Any], to pipe: Pipe) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let newline = "\n".data(using: .utf8) else {
            return
        }

        pipe.fileHandleForWriting.write(data)
        pipe.fileHandleForWriting.write(newline)
    }

    private func cleanup(process: Process, stdinPipe: Pipe, stdoutPipe: Pipe, stderrPipe: Pipe) {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        try? stdinPipe.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
        }
    }

    private func safeEnvironment() -> [String: String] {
        [
            "HOME": NSHomeDirectory(),
            "LOGNAME": NSUserName(),
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "TMPDIR": NSTemporaryDirectory(),
            "USER": NSUserName()
        ]
    }
}

private final class LineCollector {
    private let maxBufferBytes = 1_048_576
    private let maxStoredLines = 8
    private let queue = DispatchQueue(label: "CodexUsage.LineCollector")
    private var buffer = Data()
    private var linesByID: [Int: Data] = [:]
    private var waiters: [Int: DispatchSemaphore] = [:]

    func append(_ data: Data) {
        guard !data.isEmpty else {
            return
        }

        queue.sync {
            buffer.append(data)
            if buffer.count > maxBufferBytes {
                buffer.removeFirst(buffer.count - maxBufferBytes)
            }
            collectLines()
        }
    }

    func waitForLine(id: Int, timeout: TimeInterval) throws -> Data {
        let semaphore = queue.sync { () -> DispatchSemaphore in
            if linesByID[id] != nil {
                let semaphore = DispatchSemaphore(value: 1)
                return semaphore
            }

            let semaphore = DispatchSemaphore(value: 0)
            waiters[id] = semaphore
            return semaphore
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw ProcessTimeoutError()
        }

        return try queue.sync {
            guard let line = linesByID[id] else {
                throw ProcessTimeoutError()
            }
            return line
        }
    }

    private func collectLines() {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            var line = buffer[..<newlineIndex]
            if line.last == 0x0D {
                line = line.dropLast()
            }
            buffer.removeSubrange(...newlineIndex)

            guard let id = responseID(in: Data(line)) else {
                continue
            }
            linesByID[id] = Data(line)
            trimStoredLinesIfNeeded()
            waiters[id]?.signal()
            waiters[id] = nil
        }
    }

    private func trimStoredLinesIfNeeded() {
        guard linesByID.count > maxStoredLines else {
            return
        }
        let storedIDsToRemove = linesByID.keys.sorted().prefix(linesByID.count - maxStoredLines)
        for id in storedIDsToRemove {
            linesByID[id] = nil
        }
    }

    private func responseID(in line: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let id = object["id"] as? Int else {
            return nil
        }
        return id
    }
}

private final class ErrorCollector {
    private let maxBytes = 65_536
    private let queue = DispatchQueue(label: "CodexUsage.ErrorCollector")
    private var data = Data()

    func append(_ newData: Data) {
        guard !newData.isEmpty else {
            return
        }
        queue.sync {
            data.append(newData)
            if data.count > maxBytes {
                data.removeFirst(data.count - maxBytes)
            }
        }
    }

    func text() -> String {
        queue.sync {
            String(data: data, encoding: .utf8) ?? ""
        }
    }
}

private struct ProcessTimeoutError: Error {}

private struct AppServerError: Error {
    let message: String
}
