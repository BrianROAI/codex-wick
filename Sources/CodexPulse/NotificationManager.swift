#if os(macOS)
import Foundation
import UserNotifications
import CodexPulseCore

final class NotificationManager {
    private var lastAlertAt: Date?
    private var lastSeverity: AnomalySeverity = .normal

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyIfNeeded(
        report: AnomalyReport,
        observation: CodexObservation,
        enabled: Bool
    ) {
        guard enabled, report.severity >= .warning else { return }

        let now = Date()

        if let lastAlertAt,
           now.timeIntervalSince(lastAlertAt) < 10 * 60,
           report.severity <= lastSeverity {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Codex Wick: \(report.headline)"
        content.body = report.detail

        if report.severity >= .high {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }

        lastAlertAt = now
        lastSeverity = report.severity
    }
}
#endif
