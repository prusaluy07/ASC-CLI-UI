import Foundation

// MARK: - Typed mirror payloads (Phase 3c: iOS dashboard)

/// Payload of the `storedMetrics` mirror section, as produced by the macOS app's
/// `MetricsEngine.mirrorPayloadJSON`: 7-day sales aggregates plus a 14-day daily
/// trend suitable for charting on the consumer.
public struct StoredMetricsPayload: Codable, Equatable, Sendable {
    public let appId: String?
    public let days: Int?
    public let downloads: Int
    public let proceeds: Double
    public let returns: Int
    public let trend: [MetricsTrendPoint]

    public init(appId: String? = nil,
                days: Int? = nil,
                downloads: Int,
                proceeds: Double,
                returns: Int,
                trend: [MetricsTrendPoint]) {
        self.appId = appId
        self.days = days
        self.downloads = downloads
        self.proceeds = proceeds
        self.returns = returns
        self.trend = trend
    }

    /// Defensive decode: `nil` on any parse miss so the UI simply omits the card.
    public static func decode(_ json: String) -> StoredMetricsPayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StoredMetricsPayload.self, from: data)
    }

    /// Whether the trend carries any non-zero proceeds (drives showing a proceeds chart).
    public var hasProceeds: Bool {
        proceeds > 0 || trend.contains { $0.proceeds > 0 }
    }
}

/// Payload of the `marketRank` mirror section, as produced by the macOS app's
/// `MarketEngine.mirrorRankJSON`: the app's public chart position at capture time.
public struct MarketRankPayload: Codable, Equatable, Sendable {
    public let country: String
    public let chart: String
    public let rank: Int
    public let name: String
    /// Rank change vs the previous feed capture; negative means the app climbed
    /// (smaller rank number). `nil` when there is no previous capture.
    public let delta: Int?

    public init(country: String, chart: String, rank: Int, name: String, delta: Int? = nil) {
        self.country = country
        self.chart = chart
        self.rank = rank
        self.name = name
        self.delta = delta
    }

    /// Defensive decode: `nil` on any parse miss so the UI simply omits the card.
    public static func decode(_ json: String) -> MarketRankPayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MarketRankPayload.self, from: data)
    }
}

public extension MetricsTrendPoint {
    /// `date` parsed from its `yyyy-MM-dd` form, for plotting on a time axis.
    /// `nil` for malformed dates so charts can skip the point instead of misplacing it.
    var day: Date? {
        MirrorInsightsDate.parse(date)
    }
}

/// Shared `yyyy-MM-dd` parser used by the mirror dashboard (UTC, POSIX locale, cached).
public enum MirrorInsightsDate {
    private static let formatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt
    }()

    public static func parse(_ day: String) -> Date? {
        formatter.date(from: day)
    }
}
