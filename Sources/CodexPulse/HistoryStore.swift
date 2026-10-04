#if os(macOS)
import Foundation
import CodexPulseCore

final class HistoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retentionDays: Double = 30

    init() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = support.appendingPathComponent("Codex Wick", isDirectory: true)
        let legacy = support
            .appendingPathComponent("Codex Pulse", isDirectory: true)
            .appendingPathComponent("observations.jsonl")

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("observations.jsonl")

        if !fm.fileExists(atPath: fileURL.path),
           fm.fileExists(atPath: legacy.path) {
            try? fm.copyItem(at: legacy, to: fileURL)
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [CodexObservation] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        let cutoff = Date().addingTimeInterval(-retentionDays * 24 * 3600)

        return text
            .split(separator: "\n")
            .compactMap { line -> CodexObservation? in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(CodexObservation.self, from: data)
            }
            .filter { $0.observedAt >= cutoff }
            .sorted { $0.observedAt < $1.observedAt }
    }

    func append(_ observation: CodexObservation) throws {
        let data = try encoder.encode(observation)
        var line = data
        line.append(0x0A)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }

        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    func compactIfNeeded(history: [CodexObservation]) {
        guard history.count > 90_000 else { return }

        let cutoff = Date().addingTimeInterval(-retentionDays * 24 * 3600)
        let kept = history.filter { $0.observedAt >= cutoff }

        let body = kept
            .compactMap { try? encoder.encode($0) }
            .map { data -> Data in
                var line = data
                line.append(0x0A)
                return line
            }
            .reduce(into: Data()) { $0.append($1) }

        try? body.write(to: fileURL, options: .atomic)
    }
}
#endif
