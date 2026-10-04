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

    init() {
        let loaded = store.load()
        history = loaded
        current = loaded.last
        pollIntervalSeconds = UserDefaults.standard.object(forKey: "pollIntervalSeconds") as? Double ?? 30
        alertsEnabled = UserDefaults.standard.object(forKey: "alertsEnabled") as? Bool ?? true
        codexPathOverride = UserDefaults.standard.string(forKey: "codexPathOverride") ?? ""
        hudVisible = UserDefaults.standard.object(forKey: "hudVisible") as? Bool ?? true
        hudClickThrough = UserDefaults.standard.object(forKey: "hudClickThrough") as? Bool ?? false
        darkMode = UserDefaults.standard.object(forKey: "darkMode") as? Bool ?? false

        if let current {
            anomaly = AnomalyDetector.evaluate(history: Array(loaded.dropLast()), current: current)
        }
    }

    deinit {
        loopTask?.cancel()
    }

    func start() {
        guard loopTask == nil else { return }
        notifications.requestAuthorization()

        loopTask = Task { [weak self] in
            guard let self else { return }
            await refresh()

            while !Task.isCancelled {
                let seconds = max(10, pollIntervalSeconds)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await probe.fetchRateLimits(codexPathOverride: codexPathOverride.nilIfBlank)
            let observation = ObservationFactory.make(from: response)
            let report = AnomalyDetector.evaluate(history: history, current: observation)

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

        UserDefaults.standard.set(pollIntervalSeconds, forKey: "pollIntervalSeconds")
        UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled")
        UserDefaults.standard.set(codexPathOverride, forKey: "codexPathOverride")
        UserDefaults.standard.set(hudVisible, forKey: "hudVisible")
        UserDefaults.standard.set(hudClickThrough, forKey: "hudClickThrough")
        UserDefaults.standard.set(darkMode, forKey: "darkMode")

        HUDController.shared.applySettings(monitor: self)
    }

    func change(seconds: TimeInterval) -> UsageChange? {
        guard let current else { return nil }
        return HistoryMetrics.change(history: history, current: current, seconds: seconds)
    }

    var hourlyBurnRate: Double? {
        guard let current else { return nil }
        return HistoryMetrics.hourlyBurnRate(history: history, current: current)
    }

    var menuTitle: String {
        if let balance = current?.creditBalance {
            let prefix = anomaly.severity >= .warning ? "⚠ " : ""
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
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
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

    static func delta(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value > 0 { return "−" + credits(value) }
        if value < 0 { return "+" + credits(abs(value)) }
        return "0"
    }
}
#endif
