import Foundation

// MARK: - Period comparison

public struct MetricsPeriodComparison: Sendable, Equatable {
    public let current: AppMetricsSummary
    public let previous: AppMetricsSummary
    public let days: Int

    public init(current: AppMetricsSummary, previous: AppMetricsSummary, days: Int) {
        self.current = current
        self.previous = previous
        self.days = days
    }
}

/// Maps locally stored sales-report aggregates into ``AnalyticsMetric`` values for the dashboard.
public enum StoredAnalyticsMapper {
    public static func weekMetrics(comparison: MetricsPeriodComparison) -> [LocKey: AnalyticsMetric] {
        buildMetrics(current: comparison.current, previous: comparison.previous)
    }

    public static func buildMetrics(current: AppMetricsSummary,
                                    previous: AppMetricsSummary) -> [LocKey: AnalyticsMetric] {
        [
            .anFirstDownloads: metric(Double(current.firstDownloads), prev: Double(previous.firstDownloads)),
            .anRedownloads: metric(Double(current.redownloads), prev: Double(previous.redownloads)),
            .anUpdates: metric(Double(current.updates), prev: Double(previous.updates)),
            .anProceeds: metric(current.proceeds, prev: previous.proceeds),
            .anIap: metric(Double(current.iapUnits), prev: Double(previous.iapUnits)),
            .anReturns: metric(Double(current.returns), prev: Double(previous.returns)),
            .anActiveSubs: metric(Double(current.subscriptionUnits), prev: Double(previous.subscriptionUnits)),
            .anPaidSubs: metric(Double(current.subscriptionProceeds), prev: Double(previous.subscriptionProceeds)),
        ]
    }

    private static func metric(_ value: Double, prev: Double) -> AnalyticsMetric {
        AnalyticsMetric(
            label: "",
            value: value,
            delta: percentDelta(current: value, previous: prev),
            unit: nil,
            status: value == 0 && prev == 0 ? "unavailable" : "available",
            reason: nil
        )
    }

    public static func percentDelta(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return current > 0 ? 100 : nil }
        return (current - previous) / previous * 100
    }
}
