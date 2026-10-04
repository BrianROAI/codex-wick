#if os(macOS)
import Combine
import Foundation
import CodexPulseCore

@MainActor
final class MonitorModel: ObservableObject {
    static let shared = MonitorModel()

    @Published var current: CodexObservation?
    @Published var history: [CodexObservation]
    @Published var anomaly: AnomalyReport = .normal
    @Published var lastError: String?
    @Published var isRefreshing = false
    @Published private(set) var clock = Date()
    @Published var pollIntervalSeconds: Double
    @Published var alertsEnabled: Bool
    @Published var codexPathOverride: String
    @Published var hudVisible: Bool
    @Published var hudClickThrough: Bool
    @Published var darkMode: Bool

    private let store = HistoryStore()
    private let probe = CodexAppServerProbe()
    private let notifications = NotificationManager()
    private var loopTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    init() {
        let loaded = store.load()
        history = loaded
        current = loaded.last
        pollIntervalSeconds = UserDefaults.standard.object(forKey: "pollIntervalSeconds") as? Double ?? 30
        alertsEnabled = UserDefaults.standard.object(forKey: "alertsEnabled") as? Bool ?? true
        codexPathOverride = UserDefaults.standard.string(forKey: "codexPathOverride") ?? ""
        hudVisible = UserDefaults.standard.object(forKey: "hudVisible") as? Bool ?? true
        hudClickThrough = UserDefaults.standard.object(forKey: "hudClickThrough") as? Bool ?? false
        darkMode = UserDefaults.standard.object(forKey: "darkMode") as? Bool ?? true

        if let current {
            anomaly = AnomalyDetector.evaluate(
                history: Array(loaded.dropLast()),
                current: current
            )
        }
    }

    deinit {
        loopTask?.cancel()
        heartbeatTask?.cancel()
    }

    func start() {
        guard loopTask == nil else { return }

        notifications.requestAuthorization()
        startHeartbeat()

        loopTask = Task { [weak self] in
            guard let self else { return }

            await refresh()

            while !Task.isCancelled {
                let seconds = max(10, pollIntervalSeconds)
                try? await Task.sleep(
                    nanoseconds: UInt64(seconds * 1_000_000_000)
                )

                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)

                if Task.isCancelled { break }
                self?.clock = Date()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        clock = Date()

        defer {
            isRefreshing = false
            clock = Date()
        }

        do {
            let response = try await probe.fetchRateLimits(
                codexPathOverride: codexPathOverride.nilIfBlank
            )

            let observation = ObservationFactory.make(from: response)
            let report = AnomalyDetector.evaluate(
                history: history,
                current: observation
            )

            try store.append(observation)
            history.append(observation)

            let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
            history.removeAll { $0.observedAt < cutoff }
            store.compactIfNeeded(history: history)

            current = observation
            anomaly = report
            lastError = nil

            notifications.notifyIfNeeded(
                report: report,
                observation: observation,
                enabled: alertsEnabled
            )
        } catch {
            lastError = String(describing: error)
        }
    }

    func saveSettings() {
        pollIntervalSeconds = max(10, pollIntervalSeconds)

        UserDefaults.standard.set(
            pollIntervalSeconds,
            forKey: "pollIntervalSeconds"
        )
        UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled")
        UserDefaults.standard.set(
            codexPathOverride,
            forKey: "codexPathOverride"
        )
        UserDefaults.standard.set(hudVisible, forKey: "hudVisible")
        UserDefaults.standard.set(
            hudClickThrough,
            forKey: "hudClickThrough"
        )
        UserDefaults.standard.set(darkMode, forKey: "darkMode")

        HUDController.shared.applySettings(monitor: self)
    }

    func change(seconds: TimeInterval) -> UsageChange? {
        guard let current else { return nil }

        return HistoryMetrics.change(
            history: history,
            current: current,
            seconds: seconds
        )
    }

    var minuteBurnRate: Double? {
        guard let current else { return nil }

        return HistoryMetrics.minuteBurnRate(
            history: history,
            current: current
        )
    }

    var hourlyBurnRate: Double? {
        guard let current else { return nil }

        return HistoryMetrics.hourlyBurnRate(
            history: history,
            current: current
        )
    }

    var staleAfterSeconds: TimeInterval {
        max(60, pollIntervalSeconds * 2.5)
    }

    func isStale(at now: Date) -> Bool {
        guard let observedAt = current?.observedAt else { return true }
        return now.timeIntervalSince(observedAt) > staleAfterSeconds
    }

    func freshnessText(at now: Date) -> String {
        guard let observedAt = current?.observedAt else {
            return "No successful sample yet"
        }

        let age = max(0, now.timeIntervalSince(observedAt))

        if age < 5 { return "Updated just now" }
        if age < 60 { return "Updated \(Int(age))s ago" }
        if age < 3_600 { return "Updated \(Int(age / 60))m ago" }
        return "Updated \(Int(age / 3_600))h ago"
    }

    func freshnessCompactText(at now: Date) -> String {
        guard let observedAt = current?.observedAt else {
            return "NO SAMPLE"
        }

        let age = max(0, now.timeIntervalSince(observedAt))
        let ageText: String

        if age < 60 {
            ageText = "\(Int(age))s"
        } else if age < 3_600 {
            ageText = "\(Int(age / 60))m"
        } else {
            ageText = "\(Int(age / 3_600))h"
        }

        return isStale(at: now)
            ? "STALE \(ageText)"
            : "UPDATED \(ageText)"
    }

    var menuTitle: String {
        if let balance = current?.creditBalance {
            let prefix: String

            if isStale(at: clock) {
                prefix = "⏳ "
            } else if anomaly.severity >= .warning {
                prefix = "⚠ "
            } else {
                prefix = ""
            }

            return prefix + NumberFormat.compact(balance)
        }

        if let weekly = current?.weeklyUsedPercent {
            return String(format: "%.0f%%", 100 - weekly)
        }

        return "Wick"
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

enum NumberFormat {
    static func credits(_ value: Double?) -> String {
        guard let value else { return "—" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2

        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.0f", value)
    }

    static func compact(_ value: Double) -> String {
        if abs(value) >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }

        if abs(value) >= 1_000 {
            return String(format: "%.1fk", value / 1_000)
        }

        return String(format: "%.0f", value)
    }

    static func rate(_ value: Double?) -> String {
        guard let value else { return "—" }

        let magnitude = abs(value)

        if magnitude >= 1_000 {
            return compact(value)
        }

        if magnitude >= 100 {
            return String(format: "%.0f", value)
        }

        if magnitude >= 10 {
            return String(format: "%.1f", value)
        }

        return String(format: "%.2f", value)
    }

    static func delta(_ value: Double?) -> String {
        guard let value else { return "—" }

        if value > 0 { return "−" + credits(value) }
        if value < 0 { return "+" + credits(abs(value)) }
        return "0"
    }
}
#endif
