#if os(macOS)
import Foundation
import CodexPulseCore

struct CodexProbeError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

final class CodexAppServerProbe {
    func fetchRateLimits(codexPathOverride: String?) async throws -> AccountRateLimitsResponse {
        try await Task.detached(priority: .utility) {
            let executable = try CodexExecutableResolver.resolve(override: codexPathOverride)
            return try Self.fetchSynchronously(executable: executable)
        }.value
    }

    private static func fetchSynchronously(executable: URL) throws -> AccountRateLimitsResponse {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server"]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw CodexProbeError(message: "Unable to launch Codex at \(executable.path): \(error.localizedDescription)")
        }

        let timeout = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 12, execute: timeout)
        defer {
            timeout.cancel()
            try? stdin.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }

        let writer = stdin.fileHandleForWriting
        let reader = JSONLineReader(handle: stdout.fileHandleForReading)

        try writeJSONLine([
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "codex_wick",
                    "title": "Codex Wick",
                    "version": "0.2.0"
                ]
            ]
        ], to: writer)

        guard try waitForResponse(id: 1, reader: reader) else {
            throw probeFailure(process: process, stderr: stderr, fallback: "Codex app-server did not complete initialization.")
        }

        try writeJSONLine(["method": "initialized"], to: writer)
        try writeJSONLine([
            "id": 2,
            "method": "account/rateLimits/read",
            "params": ["excludeResetCreditDetails": true]
        ], to: writer)

        while let line = try reader.nextLine() {
            if let response = try RateLimitsParser.parseRateLimitsResponse(line: line, expectedRequestID: 2) {
                return response
            }
        }

        throw probeFailure(process: process, stderr: stderr, fallback: "Codex app-server closed before returning rate limits.")
    }

    private static func waitForResponse(id: Int, reader: JSONLineReader) throws -> Bool {
        while let line = try reader.nextLine() {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let responseID = object["id"] as? Int, responseID == id {
                if let error = object["error"] as? [String: Any] {
                    throw CodexProbeError(message: error["message"] as? String ?? "Unknown initialize error")
                }
                return true
            }
        }
        return false
    }

    private static func writeJSONLine(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object, options: [])
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private static func probeFailure(process: Process, stderr: Pipe, fallback: String) -> CodexProbeError {
        if process.isRunning { process.terminate() }
        let data = stderr.fileHandleForReading.availableData
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CodexProbeError(message: (text?.isEmpty == false ? text! : fallback))
    }
}

private final class JSONLineReader {
    private let handle: FileHandle
    private var buffer = Data()

    init(handle: FileHandle) { self.handle = handle }

    func nextLine() throws -> String? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)
                return String(data: lineData, encoding: .utf8)
            }

            let chunk = handle.availableData
            if chunk.isEmpty {
                guard !buffer.isEmpty else { return nil }
                defer { buffer.removeAll() }
                return String(data: buffer, encoding: .utf8)
            }
            buffer.append(chunk)
        }
    }
}

private enum CodexExecutableResolver {
    static func resolve(override: String?) throws -> URL {
        let fm = FileManager.default
        if let override, !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expanded = NSString(string: override).expandingTildeInPath
            if fm.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
            throw CodexProbeError(message: "Configured Codex executable is not runnable: \(expanded)")
        }

        var candidates: [String] = []
        if let envPath = ProcessInfo.processInfo.environment["CODEX_BIN"] { candidates.append(envPath) }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
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

        let nvmRoot = URL(fileURLWithPath: home).appendingPathComponent(".nvm/versions/node")
        if let versions = try? fm.contentsOfDirectory(at: nvmRoot, includingPropertiesForKeys: nil) {
            candidates.append(contentsOf: versions.sorted { $0.lastPathComponent > $1.lastPathComponent }.map {
                $0.appendingPathComponent("bin/codex").path
            })
        }

        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            let expanded = NSString(string: candidate).expandingTildeInPath
            if fm.isExecutableFile(atPath: expanded) { return URL(fileURLWithPath: expanded) }
        }

        throw CodexProbeError(message: "Codex executable not found. Set its path in Codex Wick settings.")
    }
}
#endif
