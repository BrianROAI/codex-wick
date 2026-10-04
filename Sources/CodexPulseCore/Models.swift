import Foundation

public struct CodexObservation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var observedAt: Date
    public var creditBalance: Double?
    public var hasCredits: Bool?
    public var unlimitedCredits: Bool?
    public var shortWindowUsedPercent: Double?
    public var shortWindowDurationMinutes: Double?
    public var shortWindowResetsAt: Date?
    public var weeklyUsedPercent: Double?
    public var weeklyResetsAt: Date?
    public var planType: String?
    public var ordinaryUsageAllowed: Bool?

    public init(
        id: UUID = UUID(),
        observedAt: Date,
        creditBalance: Double? = nil,
        hasCredits: Bool? = nil,
        unlimitedCredits: Bool? = nil,
        shortWindowUsedPercent: Double? = nil,
        shortWindowDurationMinutes: Double? = nil,
        shortWindowResetsAt: Date? = nil,
        weeklyUsedPercent: Double? = nil,
        weeklyResetsAt: Date? = nil,
        planType: String? = nil,
        ordinaryUsageAllowed: Bool? = nil
    ) {
        self.id = id
        self.observedAt = observedAt
        self.creditBalance = creditBalance
        self.hasCredits = hasCredits
        self.unlimitedCredits = unlimitedCredits
        self.shortWindowUsedPercent = shortWindowUsedPercent
        self.shortWindowDurationMinutes = shortWindowDurationMinutes
        self.shortWindowResetsAt = shortWindowResetsAt
        self.weeklyUsedPercent = weeklyUsedPercent
        self.weeklyResetsAt = weeklyResetsAt
        self.planType = planType
        self.ordinaryUsageAllowed = ordinaryUsageAllowed
    }
}

public struct AccountRateLimitsResponse: Decodable, Sendable {
    public let ordinaryUsageAllowed: Bool?
    public let rateLimits: RateLimitSnapshot
    public let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    public let accountId: String?

    public init(
        ordinaryUsageAllowed: Bool?,
        rateLimits: RateLimitSnapshot,
        rateLimitsByLimitId: [String: RateLimitSnapshot]?,
        accountId: String?
    ) {
        self.ordinaryUsageAllowed = ordinaryUsageAllowed
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
        self.accountId = accountId
    }
}

public struct RateLimitSnapshot: Decodable, Sendable {
    public let credits: CreditsSnapshot?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let planType: String?
    public let limitId: String?
    public let limitName: String?

    public init(credits: CreditsSnapshot?, primary: RateLimitWindow?, secondary: RateLimitWindow?, planType: String?, limitId: String?, limitName: String?) {
        self.credits = credits
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.limitId = limitId
        self.limitName = limitName
    }
}

public struct CreditsSnapshot: Decodable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct RateLimitWindow: Decodable, Sendable {
    public let usedPercent: Double
    public let windowDurationMins: Double?
    public let resetsAt: Double?

    public init(usedPercent: Double, windowDurationMins: Double?, resetsAt: Double?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public enum RateLimitsParserError: Error, CustomStringConvertible, Equatable {
    case malformedJSON
    case rpcError(code: Int?, message: String)
    case missingResult

    public var description: String {
        switch self {
        case .malformedJSON: return "Codex returned malformed JSON."
        case let .rpcError(code, message):
            if let code { return "Codex app-server RPC error \(code): \(message)" }
            return "Codex app-server RPC error: \(message)"
        case .missingResult: return "Codex rate-limit response did not include a result payload."
        }
    }
}

public enum RateLimitsParser {
    private struct Envelope: Decodable {
        struct RPCError: Decodable {
            let code: Int?
            let message: String
        }
        let id: FlexibleID?
        let result: AccountRateLimitsResponse?
        let error: RPCError?
    }

    private enum FlexibleID: Decodable {
        case integer(Int)
        case string(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Int.self) {
                self = .integer(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else {
                throw DecodingError.typeMismatch(
                    FlexibleID.self,
                    .init(codingPath: decoder.codingPath, debugDescription: "Expected integer or string RPC id")
                )
            }
        }
    }

    public static func parseRateLimitsResponse(line: String, expectedRequestID: Int = 2) throws -> AccountRateLimitsResponse? {
        guard let data = line.data(using: .utf8) else { throw RateLimitsParserError.malformedJSON }

        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { return nil }

        guard case let .integer(id)? = envelope.id, id == expectedRequestID else { return nil }

        if let rpcError = envelope.error {
            throw RateLimitsParserError.rpcError(code: rpcError.code, message: rpcError.message)
        }

        guard let result = envelope.result else { throw RateLimitsParserError.missingResult }
        return result
    }
}

public enum ObservationFactory {
    public static func make(from response: AccountRateLimitsResponse, observedAt: Date = Date()) -> CodexObservation {
        let snapshot = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        let windows = [snapshot.primary, snapshot.secondary].compactMap { $0 }

        let weekly = windows.first(where: { window in
            guard let duration = window.windowDurationMins else { return false }
            return abs(duration - 10_080) < 1
        }) ?? windows.max(by: { ($0.windowDurationMins ?? 0) < ($1.windowDurationMins ?? 0) })

        let shortWindow = windows
            .filter { $0.windowDurationMins != weekly?.windowDurationMins }
            .min(by: { ($0.windowDurationMins ?? .greatestFiniteMagnitude) < ($1.windowDurationMins ?? .greatestFiniteMagnitude) })

        let balance = snapshot.credits?.balance.flatMap(Double.init)

        return CodexObservation(
            observedAt: observedAt,
            creditBalance: balance,
            hasCredits: snapshot.credits?.hasCredits,
            unlimitedCredits: snapshot.credits?.unlimited,
            shortWindowUsedPercent: shortWindow?.usedPercent,
            shortWindowDurationMinutes: shortWindow?.windowDurationMins,
            shortWindowResetsAt: date(fromUnixSeconds: shortWindow?.resetsAt),
            weeklyUsedPercent: weekly?.usedPercent,
            weeklyResetsAt: date(fromUnixSeconds: weekly?.resetsAt),
            planType: snapshot.planType,
            ordinaryUsageAllowed: response.ordinaryUsageAllowed
        )
    }

    private static func date(fromUnixSeconds value: Double?) -> Date? {
        guard let value else { return nil }
        return Date(timeIntervalSince1970: value)
    }
}
