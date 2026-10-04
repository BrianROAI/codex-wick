#if os(macOS)
import Darwin
import Foundation
import CodexPulseCore

struct CodexProbeError: Error, CustomStringConvertible, Sendable {
    let message: String
    var description: String { message }
}

struct CodexAppServerProbe: Sendable {
    func fetchRateLimits(
        codexPathOverride: String?
    ) async throws -> AccountRateLimitsResponse {
        let executable = try CodexExecutableResolver.resolve(
            override: codexPathOverride
        )

        return try await AppServerProbeSession(
            executable: executable
        ).run()
    }
}

// All mutable session state is confined to `queue`; callback closures only
// enqueue work onto that same serial queue.
private final class AppServerProbeSession: @unchecked Sendable {
    private enum Phase {
        case initializing
        case readingRateLimits
    }

    private let executable: URL
    private let queue = DispatchQueue(
        label: "io.github.BrianROAI.codexwick.app-server-probe"
    )

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?

    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()

    private var continuation:
        CheckedContinuation<AccountRateLimitsResponse, Error>?
    private var timeoutWorkItem: DispatchWorkItem?
    private var phase: Phase = .initializing
    private var finished = false

    private let phaseTimeoutSeconds: TimeInterval = 12

    init(executable: URL) {
        self.executable = executable
    }

    func run() async throws -> AccountRateLimitsResponse {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.start(continuation: continuation)
            }
        }
    }

    private func start(
        continuation: CheckedContinuation<AccountRateLimitsResponse, Error>
    ) {
        self.continuation = continuation

        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server"]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        self.process = process
        stdinHandle = stdin.fileHandleForWriting
        stdoutHandle = stdout.fileHandleForReading
        stderrHandle = stderr.fileHandleForReading

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let session = self else { return }

            let data: Data
            do {
                data = try Self.readAvailableData(
                    from: handle,
                    streamName: "stdout"
                )
            } catch {
                let message = String(describing: error)
                session.queue.async { [session] in
                    session.finish(
                        .failure(
                            CodexProbeError(message: message)
                        )
                    )
                }
                return
            }

            session.queue.async { [session] in
                session.consumeStdout(data)
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let session = self else { return }

            let data: Data
            do {
                data = try Self.readAvailableData(
                    from: handle,
                    streamName: "stderr"
                )
            } catch {
                let message = String(describing: error)
                session.queue.async { [session] in
                    session.finish(
                        .failure(
                            CodexProbeError(message: message)
                        )
                    )
                }
                return
            }

            guard !data.isEmpty else { return }

            session.queue.async { [session] in
                session.stderrBuffer.append(data)
            }
        }

        process.terminationHandler = { [weak self] process in
            guard let session = self else { return }

            let status = process.terminationStatus
            session.queue.async { [session] in
                session.processTerminated(status: status)
            }
        }

        do {
            try process.run()
        } catch {
            finish(
                .failure(
                    CodexProbeError(
                        message: "Unable to launch Codex at \(executable.path): \(error.localizedDescription)"
                    )
                )
            )
            return
        }

        do {
            try writeJSONLine([
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "codex_wick",
                        "title": "Codex Wick",
                        "version": "0.2.1"
                    ]
                ]
            ])
        } catch {
            finish(.failure(error))
            return
        }

        phase = .initializing
        armTimeout(
            message: "Codex app-server timed out during initialization."
        )
    }

    private static func readAvailableData(
        from handle: FileHandle,
        streamName: String
    ) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 65_536)

        while true {
            let count = bytes.withUnsafeMutableBytes { buffer -> Int in
                guard let baseAddress = buffer.baseAddress else { return 0 }
                return Darwin.read(
                    handle.fileDescriptor,
                    baseAddress,
                    buffer.count
                )
            }

            if count > 0 {
                return Data(bytes.prefix(count))
            }

            if count == 0 {
                return Data()
            }

            if errno == EINTR {
                continue
            }

            throw CodexProbeError(
                message: "Codex app-server \(streamName) read failed: "
                    + String(cString: strerror(errno))
            )
        }
    }

    private func consumeStdout(_ data: Data) {
        guard !finished else { return }

        if data.isEmpty {
            return
        }

        stdoutBuffer.append(data)

        while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
            let lineData = stdoutBuffer[..<newline]
            stdoutBuffer.removeSubrange(...newline)

            guard let line = String(
                data: lineData,
                encoding: .utf8
            ) else {
                continue
            }

            handleLine(line)

            if finished {
                return
            }
        }
    }

    private func handleLine(_ line: String) {
        switch phase {
        case .initializing:
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(
                    with: data
                  ) as? [String: Any],
                  let responseID = object["id"] as? Int,
                  responseID == 1 else {
                return
            }

            if let error = object["error"] as? [String: Any] {
                finish(
                    .failure(
                        CodexProbeError(
                            message: error["message"] as? String
                                ?? "Unknown initialize error"
                        )
                    )
                )
                return
            }

            timeoutWorkItem?.cancel()
            phase = .readingRateLimits

            do {
                try writeJSONLine(["method": "initialized"])
                try writeJSONLine([
                    "id": 2,
                    "method": "account/rateLimits/read",
                    "params": [
                        "excludeResetCreditDetails": true
                    ]
                ])
            } catch {
                finish(.failure(error))
                return
            }

            armTimeout(
                message: "Codex app-server timed out reading rate limits."
            )

        case .readingRateLimits:
            do {
                if let response = try RateLimitsParser.parseRateLimitsResponse(
                    line: line,
                    expectedRequestID: 2
                ) {
                    finish(.success(response))
                }
            } catch {
                finish(.failure(error))
            }
        }
    }

    private func writeJSONLine(
        _ object: [String: Any]
    ) throws {
        guard let stdinHandle else {
            throw CodexProbeError(
                message: "Codex app-server stdin is unavailable."
            )
        }

        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: []
        )
        data.append(0x0A)

        do {
            try stdinHandle.write(contentsOf: data)
        } catch {
            throw CodexProbeError(
                message: "Codex app-server write failed: \(error.localizedDescription)"
            )
        }
    }

    private func armTimeout(message: String) {
        timeoutWorkItem?.cancel()

        // Intentionally retain the session until this bounded phase either
        // completes or times out. finish() clears timeoutWorkItem and breaks
        // the temporary cycle.
        let workItem = DispatchWorkItem { [self] in
            finish(
                .failure(
                    CodexProbeError(message: message)
                )
            )
        }

        timeoutWorkItem = workItem
        queue.asyncAfter(
            deadline: .now() + phaseTimeoutSeconds,
            execute: workItem
        )
    }

    private func processTerminated(status: Int32) {
        guard !finished else { return }

        let stderrText = String(
            data: stderrBuffer,
            encoding: .utf8
        )?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let fallback: String
        switch phase {
        case .initializing:
            fallback = "Codex app-server exited during initialization."
        case .readingRateLimits:
            fallback = "Codex app-server exited before returning rate limits."
        }

        let suffix = status == 0 ? "" : " (status \(status))"

        finish(
            .failure(
                CodexProbeError(
                    message: (stderrText?.isEmpty == false
                        ? stderrText!
                        : fallback) + suffix
                )
            )
        )
    }

    private func finish(
        _ result: Result<AccountRateLimitsResponse, Error>
    ) {
        guard !finished else { return }
        finished = true

        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil

        let process = self.process
        process?.terminationHandler = nil

        try? stdinHandle?.close()
        try? stdoutHandle?.close()
        try? stderrHandle?.close()

        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil

        if let process, process.isRunning {
            process.terminate()

            queue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self,
                      let process = self.process,
                      process.isRunning else {
                    return
                }

                _ = Darwin.kill(
                    process.processIdentifier,
                    SIGKILL
                )
                process.waitUntilExit()
                self.process = nil
            }
        } else {
            self.process = nil
        }

        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

private enum CodexExecutableResolver {
    static func resolve(override: String?) throws -> URL {
        let fm = FileManager.default

        if let override,
           !override.trimmingCharacters(
            in: .whitespacesAndNewlines
           ).isEmpty {
            let expanded = NSString(
                string: override
            ).expandingTildeInPath

            if fm.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }

            throw CodexProbeError(
                message: "Configured Codex executable is not runnable: \(expanded)"
            )
        }

        var candidates: [String] = []

        if let envPath = ProcessInfo.processInfo.environment[
            "CODEX_BIN"
        ] {
            candidates.append(envPath)
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(
                contentsOf: path
                    .split(separator: ":")
                    .map { "\($0)/codex" }
            )
        }

        let home = fm.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "\(home)/.volta/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.cargo/bin/codex",
            "\(home)/.codex/bin/codex"
        ])

        let nvmRoot = URL(
            fileURLWithPath: home
        ).appendingPathComponent(
            ".nvm/versions/node"
        )

        if let versions = try? fm.contentsOfDirectory(
            at: nvmRoot,
            includingPropertiesForKeys: nil
        ) {
            candidates.append(
                contentsOf: versions
                    .sorted {
                        $0.lastPathComponent
                            > $1.lastPathComponent
                    }
                    .map {
                        $0.appendingPathComponent(
                            "bin/codex"
                        ).path
                    }
            )
        }

        var seen = Set<String>()

        for candidate in candidates
        where seen.insert(candidate).inserted {
            let expanded = NSString(
                string: candidate
            ).expandingTildeInPath

            if fm.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }

        throw CodexProbeError(
            message: "Codex executable not found. Set its path in Codex Wick settings."
        )
    }
}
#endif
