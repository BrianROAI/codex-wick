import Foundation

public enum AnomalySeverity: Int, Codable, Comparable, Sendable {
    case normal = 0
    case warning = 1
    case high = 2
    case critical = 3

    public static func < (lhs: AnomalySeverity, rhs: AnomalySeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct AnomalyReport: Equatable, Sendable {
    public let severity: AnomalySeverity
    public let headline: String
    public let detail: String
    public let creditDrawdownPerMinute: Double?
    public let robustZScore: Double?
    public let weeklyUsedPercentPerMinute: Double?

    public init(
        severity: AnomalySeverity,
        headline: String,
        detail: String,
        creditDrawdownPerMinute: Double?,
        robustZScore: Double?,
        weeklyUsedPercentPerMinute: Double?
    ) {
        self.severity = severity
        self.headline = headline
        self.detail = detail
        self.creditDrawdownPerMinute = creditDrawdownPerMinute
        self.robustZScore = robustZScore
        self.weeklyUsedPercentPerMinute = weeklyUsedPercentPerMinute
    }

    public static let normal = AnomalyReport(
        severity: .normal,
        headline: "Normal",
        detail: "Consumption is within the recent baseline.",
        creditDrawdownPerMinute: nil,
        robustZScore: nil,
        weeklyUsedPercentPerMinute: nil
    )
}

public enum AnomalyDetector {
    public static func evaluate(history: [CodexObservation], current: CodexObservation) -> AnomalyReport {
        guard let previous = history.last(where: { $0.observedAt < current.observedAt }) else {
            return .normal
        }

        let elapsedMinutes = current.observedAt.timeIntervalSince(previous.observedAt) / 60
        guard elapsedMinutes > 0.05, elapsedMinutes <= 10 else {
            return .normal
        }

        var severity: AnomalySeverity = .normal
        var reasons: [String] = []
        var currentCreditRate: Double?
        var zScore: Double?

        if let oldBalance = previous.creditBalance, let newBalance = current.creditBalance {
            let drawdown = oldBalance - newBalance
            if drawdown > 0 {
                let rate = drawdown / elapsedMinutes
                currentCreditRate = rate

                let baseline = creditDrawdownRatesPerMinute(history: history, before: current.observedAt)
                let medianRate = median(baseline)
                let mad = median(baseline.map { abs($0 - medianRate) })
                let robustSigma = max(1, mad * 1.4826)
                let z = (rate - medianRate) / robustSigma
                zScore = z

                if baseline.count >= 8 {
                    if rate >= max(2_000, medianRate + 12 * robustSigma) || drawdown >= max(2_500, oldBalance * 0.05) {
                        severity = max(severity, .critical)
                    } else if rate >= max(750, medianRate + 8 * robustSigma) || drawdown >= max(1_000, oldBalance * 0.02) {
                        severity = max(severity, .high)
                    } else if rate >= max(200, medianRate + 5 * robustSigma) {
                        severity = max(severity, .warning)
                    }
                } else {
                    if rate >= 5_000 || drawdown >= max(5_000, oldBalance * 0.08) {
                        severity = max(severity, .critical)
                    } else if rate >= 1_500 || drawdown >= max(1_500, oldBalance * 0.03) {
                        severity = max(severity, .high)
                    } else if rate >= 500 {
                        severity = max(severity, .warning)
                    }
                }

                if severity > .normal {
                    reasons.append(String(format: "Credit drawdown %.0f/min", rate))
                }
            }
        }

        var weeklyRate: Double?
        if let oldWeekly = previous.weeklyUsedPercent,
           let newWeekly = current.weeklyUsedPercent,
           newWeekly >= oldWeekly {
            let rate = (newWeekly - oldWeekly) / elapsedMinutes
            weeklyRate = rate

            if rate >= 20 {
                severity = max(severity, .critical)
            } else if rate >= 10 {
                severity = max(severity, .high)
            } else if rate >= 5 {
                severity = max(severity, .warning)
            }

            if rate >= 5 {
                reasons.append(String(format: "Weekly allowance jumped %.1f%%/min", rate))
            }
        }

        guard severity > .normal else {
            return AnomalyReport(
                severity: .normal,
                headline: "Normal",
                detail: "Consumption is within the recent baseline.",
                creditDrawdownPerMinute: currentCreditRate,
                robustZScore: zScore,
                weeklyUsedPercentPerMinute: weeklyRate
            )
        }

        let headline: String
        switch severity {
        case .normal: headline = "Normal"
        case .warning: headline = "Unusual consumption"
        case .high: headline = "High drawdown"
        case .critical: headline = "Critical drawdown"
        }

        let detail = reasons.isEmpty ? "Consumption moved outside the expected envelope." : reasons.joined(separator: " · ")
        return AnomalyReport(
            severity: severity,
            headline: headline,
            detail: detail,
            creditDrawdownPerMinute: currentCreditRate,
            robustZScore: zScore,
            weeklyUsedPercentPerMinute: weeklyRate
        )
    }

    private static func creditDrawdownRatesPerMinute(history: [CodexObservation], before: Date) -> [Double] {
        let recent = history
            .filter { before.timeIntervalSince($0.observedAt) <= 24 * 3600 && $0.observedAt < before }
            .sorted { $0.observedAt < $1.observedAt }

        guard recent.count >= 2 else { return [] }
        var rates: [Double] = []

        for index in 1..<recent.count {
            let previous = recent[index - 1]
            let current = recent[index]
            let elapsedMinutes = current.observedAt.timeIntervalSince(previous.observedAt) / 60
            guard elapsedMinutes >= 0.05, elapsedMinutes <= 5,
                  let oldBalance = previous.creditBalance,
                  let newBalance = current.creditBalance else {
                continue
            }

            let drawdown = oldBalance - newBalance
            if drawdown >= 0 {
                rates.append(drawdown / elapsedMinutes)
            }
        }
        return rates
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }
}
