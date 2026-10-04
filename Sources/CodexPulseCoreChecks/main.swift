import Darwin
import Foundation
import CodexPulseCore

struct CoreCheckFailure: Error, CustomStringConvertible {
    let description: String
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CoreCheckFailure(description: message) }
}

var failures = 0

func run(_ name: String, _ body: () throws -> Void) {
    do {
        try body()
        print("PASS \(name)")
    } catch {
        failures += 1
        print("FAIL \(name): \(error)")
    }
}

run("rate-limit parser") {
    let line = #"{"id":2,"result":{"ordinaryUsageAllowed":true,"accountId":"acct","rateLimits":{"planType":"pro","credits":{"hasCredits":true,"unlimited":false,"balance":"62500"},"primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":1791110000},"secondary":{"usedPercent":41,"windowDurationMins":10080,"resetsAt":1791710000}}}}"#

    guard let response = try RateLimitsParser.parseRateLimitsResponse(line: line) else {
        throw CoreCheckFailure(description: "parser returned no response")
    }

    let observation = ObservationFactory.make(
        from: response,
        observedAt: Date(timeIntervalSince1970: 1_790_000_000)
    )

    try require(observation.creditBalance == 62_500, "credit balance mismatch")
    try require(observation.shortWindowUsedPercent == 12, "short-window usage mismatch")
    try require(observation.weeklyUsedPercent == 41, "weekly usage mismatch")
    try require(observation.planType == "pro", "plan type mismatch")
    try require(response.accountId == "acct", "transport account id mismatch")

    let encoded = try JSONEncoder().encode(observation)
    let encodedText = String(data: encoded, encoding: .utf8) ?? ""
    try require(
        !encodedText.contains("accountId"),
        "account id leaked into persisted observation"
    )
}

run("one-minute drawdown") {
    let start = Date(timeIntervalSince1970: 1_000)
    let old = CodexObservation(
        observedAt: start,
        creditBalance: 10_000,
        weeklyUsedPercent: 20
    )
    let current = CodexObservation(
        observedAt: start.addingTimeInterval(60),
        creditBalance: 9_850,
        weeklyUsedPercent: 21
    )

    let change = HistoryMetrics.change(
        history: [old],
        current: current,
        seconds: 60
    )

    try require(change.creditDrawdown == 150, "expected 150-credit drawdown")
    try require(change.weeklyUsedPercentDelta == 1, "expected 1% weekly delta")
}

run("one-minute burn rate normalizes sample spacing") {
    let start = Date(timeIntervalSince1970: 1_000)
    let previous = CodexObservation(
        observedAt: start.addingTimeInterval(30),
        creditBalance: 1_000
    )
    let current = CodexObservation(
        observedAt: start.addingTimeInterval(60),
        creditBalance: 970
    )

    let rate = HistoryMetrics.minuteBurnRate(
        history: [previous],
        current: current
    )

    try require(
        rate == 60,
        "expected 60 credits/min from a 30-second sample"
    )
}

run("one-minute burn rate rejects stale gap") {
    let start = Date(timeIntervalSince1970: 1_000)
    let previous = CodexObservation(
        observedAt: start,
        creditBalance: 1_000
    )
    let current = CodexObservation(
        observedAt: start.addingTimeInterval(5 * 60),
        creditBalance: 900
    )

    let rate = HistoryMetrics.minuteBurnRate(
        history: [previous],
        current: current
    )

    try require(
        rate == nil,
        "stale history produced a current minute burn rate"
    )
}

run("hour metric requires full history") {
    let start = Date(timeIntervalSince1970: 1_000)
    let old = CodexObservation(
        observedAt: start,
        creditBalance: 10_000,
        weeklyUsedPercent: 20
    )
    let current = CodexObservation(
        observedAt: start.addingTimeInterval(5 * 60),
        creditBalance: 9_500,
        weeklyUsedPercent: 21
    )

    let change = HistoryMetrics.change(
        history: [old],
        current: current,
        seconds: 3_600
    )

    try require(
        change.creditDrawdown == nil,
        "partial history was mislabeled as one hour"
    )
    try require(
        change.weeklyUsedPercentDelta == nil,
        "partial weekly history was mislabeled as one hour"
    )
}

run("large drawdown is critical") {
    let start = Date(timeIntervalSince1970: 1_000)
    var history: [CodexObservation] = []
    var balance = 20_000.0

    for minute in 0..<12 {
        history.append(
            CodexObservation(
                observedAt: start.addingTimeInterval(Double(minute) * 60),
                creditBalance: balance,
                weeklyUsedPercent: 10 + Double(minute) * 0.1
            )
        )
        balance -= 10
    }

    let current = CodexObservation(
        observedAt: start.addingTimeInterval(12 * 60),
        creditBalance: balance - 3_000,
        weeklyUsedPercent: 11.3
    )

    let report = AnomalyDetector.evaluate(
        history: history,
        current: current
    )

    try require(
        report.severity == .critical,
        "expected critical anomaly"
    )
}

run("credit reload is normal") {
    let start = Date(timeIntervalSince1970: 1_000)
    let previous = CodexObservation(
        observedAt: start,
        creditBalance: 1_000,
        weeklyUsedPercent: 25
    )
    let current = CodexObservation(
        observedAt: start.addingTimeInterval(60),
        creditBalance: 2_000,
        weeklyUsedPercent: 25.1
    )

    let report = AnomalyDetector.evaluate(
        history: [previous],
        current: current
    )

    try require(
        report.severity == .normal,
        "credit reload was misclassified"
    )
}

if failures > 0 {
    print("")
    print("\(failures) Codex Wick core check(s) failed.")
    exit(1)
}

print("")
print("All 7 Codex Wick core checks passed.")
