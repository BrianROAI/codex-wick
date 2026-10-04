#if os(macOS)
import Foundation
import CodexPulseCore

struct DerivativeOverlayPoint: Identifiable {
    let observedAt: Date
    let creditsPerHour: Double
    let mappedY: Double

    var id: Date { observedAt }
}

enum DerivativeOverlay {
    static func make(
        from observations: [CodexObservation],
        targetY: ClosedRange<Double>
    ) -> [DerivativeOverlayPoint] {
        guard observations.count > 1 else { return [] }

        var raw: [(Date, Double)] = []

        for index in 1..<observations.count {
            let previous = observations[index - 1]
            let current = observations[index]

            guard let previousBalance = previous.creditBalance,
                  let currentBalance = current.creditBalance
            else { continue }

            let hours = current.observedAt.timeIntervalSince(previous.observedAt) / 3_600
            guard hours > 0 else { continue }

            raw.append((
                current.observedAt,
                (currentBalance - previousBalance) / hours
            ))
        }

        guard !raw.isEmpty else { return [] }

        let smoothed = raw.indices.map { index -> (Date, Double) in
            let lower = max(0, index - 2)
            let upper = min(raw.count - 1, index + 2)
            let window = raw[lower...upper]
            let average = window.map(\.1).reduce(0, +) / Double(window.count)
            return (raw[index].0, average)
        }

        let values = smoothed.map(\.1)
        guard let low = values.min(), let high = values.max() else { return [] }

        let sourceSpan = max(high - low, 1)
        let targetSpan = targetY.upperBound - targetY.lowerBound

        return smoothed.map { date, value in
            let normalized = (value - low) / sourceSpan
            return DerivativeOverlayPoint(
                observedAt: date,
                creditsPerHour: value,
                mappedY: targetY.lowerBound + normalized * targetSpan
            )
        }
    }
}
#endif
