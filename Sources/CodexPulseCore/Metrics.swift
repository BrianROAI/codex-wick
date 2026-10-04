import Foundation

public struct UsageChange: Equatable, Sendable {
    public let seconds: TimeInterval
    public let creditDrawdown: Double?
    public let weeklyUsedPercentDelta: Double?

    public init(
        seconds: TimeInterval,
        creditDrawdown: Double?,
        weeklyUsedPercentDelta: Double?
    ) {
        self.seconds = seconds
        self.creditDrawdown = creditDrawdown
        self.weeklyUsedPercentDelta = weeklyUsedPercentDelta
    }
}

public enum HistoryMetrics {
    public static func change(
        history: [CodexObservation],
        current: CodexObservation,
        seconds: TimeInterval
    ) -> UsageChange {
        let cutoff = current.observedAt.addingTimeInterval(-seconds)
        let prior = history.filter { $0.observedAt < current.observedAt }

        guard let reference = closestObservation(to: cutoff, history: prior) else {
            return UsageChange(
                seconds: seconds,
                creditDrawdown: nil,
                weeklyUsedPercentDelta: nil
            )
        }

        let tolerance = max(90, seconds * 0.10)
        guard abs(reference.observedAt.timeIntervalSince(cutoff)) <= tolerance else {
            return UsageChange(
                seconds: seconds,
                creditDrawdown: nil,
                weeklyUsedPercentDelta: nil
            )
        }

        let creditDrawdown: Double?
        if let old = reference.creditBalance,
           let new = current.creditBalance {
            creditDrawdown = old - new
        } else {
            creditDrawdown = nil
        }

        let weeklyDelta: Double?
        if let old = reference.weeklyUsedPercent,
           let new = current.weeklyUsedPercent,
           new >= old {
            weeklyDelta = new - old
        } else {
            weeklyDelta = nil
        }

        return UsageChange(
            seconds: seconds,
            creditDrawdown: creditDrawdown,
            weeklyUsedPercentDelta: weeklyDelta
        )
    }

    public static func minuteBurnRate(
        history: [CodexObservation],
        current: CodexObservation,
        lookback: TimeInterval = 60
    ) -> Double? {
        let cutoff = current.observedAt.addingTimeInterval(-lookback)
        let prior = history.filter { $0.observedAt < current.observedAt }

        guard let reference = closestObservation(to: cutoff, history: prior),
              let old = reference.creditBalance,
              let new = current.creditBalance else {
            return nil
        }

        let tolerance = max(15, lookback * 0.75)
        guard abs(reference.observedAt.timeIntervalSince(cutoff)) <= tolerance else {
            return nil
        }

        let elapsed = current.observedAt.timeIntervalSince(reference.observedAt)
        guard elapsed >= max(15, lookback * 0.40),
              elapsed <= lookback + tolerance else {
            return nil
        }

        return max(0, old - new) * 60 / elapsed
    }

    public static func hourlyBurnRate(
        history: [CodexObservation],
        current: CodexObservation,
        lookback: TimeInterval = 3_600
    ) -> Double? {
        let change = change(
            history: history,
            current: current,
            seconds: lookback
        )

        guard let drawdown = change.creditDrawdown else { return nil }
        return max(0, drawdown) * 3_600 / lookback
    }

    private static func closestObservation(
        to target: Date,
        history: [CodexObservation]
    ) -> CodexObservation? {
        history.min { lhs, rhs in
            abs(lhs.observedAt.timeIntervalSince(target))
                < abs(rhs.observedAt.timeIntervalSince(target))
        }
    }
}
