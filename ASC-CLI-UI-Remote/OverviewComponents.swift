import SwiftUI
import Charts
import ASCShared

// MARK: - Formatting helpers

enum Fmt {
    /// Localized number: whole numbers without fraction digits, otherwise max 2.
    static func number(_ value: Double, percent: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        let text = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return percent ? "\(text) %" : text
    }

    static func integer(_ value: Int) -> String {
        number(Double(value))
    }

    /// Turns ENUM_LIKE_TOKENS into "Enum Like Tokens"; leaves everything else alone.
    static func prettyToken(_ s: String) -> String {
        guard s.contains("_"), s == s.uppercased() else { return s }
        return s.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

// MARK: - Stat tile

/// A small labeled headline value ("Latest build" / "482"), used in the overview grid.
struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Badges

/// Percent-change chip (▲ 12 % / ▼ 3 %). Sign carries polarity; color is redundant support.
struct DeltaBadge: View {
    let delta: Double

    private var isFlat: Bool { abs(delta) < 0.05 }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isFlat ? "arrow.right" : (delta > 0 ? "arrow.up" : "arrow.down"))
            Text(Fmt.number(abs(delta), percent: true))
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    private var color: Color {
        if isFlat { return .gray }
        return delta > 0 ? .green : .red
    }
}

/// Colored state chip for App Store / build states (same mapping as the macOS app).
struct StateBadge: View {
    let text: String

    var body: some View {
        Text(Fmt.prettyToken(text))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        let t = text.uppercased()
        let green = ["APPROVED", "ACTIVE", "READY", "ENABLED", "COMPLETED", "LIVE", "ACCEPTED", "VALID"]
        let amber = ["PENDING", "REVIEW", "WAITING", "PROCESSING", "PREPARE", "DRAFT", "PROPOSED"]
        let red = ["REJECTED", "REMOVED", "INVALID", "FAILED", "EXPIRED", "DISABLED", "CANCEL"]
        if green.contains(where: { t.contains($0) }) { return .green }
        if amber.contains(where: { t.contains($0) }) { return .orange }
        if red.contains(where: { t.contains($0) }) { return .red }
        return .gray
    }
}

// MARK: - Trend chart (storedMetrics)

/// 14-day sales trend from the mirrored `storedMetrics` payload. One measure per chart
/// (downloads *or* proceeds, never a dual axis) — the segmented picker switches between
/// them when proceeds exist.
struct TrendChartCard: View {
    @EnvironmentObject private var loc: LocalizationManager
    let payload: StoredMetricsPayload
    @State private var metric: Metric = .downloads

    enum Metric: String, CaseIterable, Identifiable {
        case downloads, proceeds
        var id: String { rawValue }
    }

    private struct TrendValue: Identifiable {
        let day: Date
        let value: Double
        var id: Date { day }
    }

    private var points: [TrendValue] {
        payload.trend.compactMap { point in
            guard let day = point.day else { return nil }
            let value = metric == .downloads ? Double(point.downloads) : point.proceeds
            return TrendValue(day: day, value: value)
        }
        .sorted { $0.day < $1.day }
    }

    private var seriesColor: Color { metric == .downloads ? .blue : .green }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(loc(.msTrendTitle))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if payload.hasProceeds {
                    Picker("", selection: $metric) {
                        Text(loc(.rmDownloads)).tag(Metric.downloads)
                        Text(loc(.anProceeds)).tag(Metric.proceeds)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 190)
                }
            }
            if points.count > 1 {
                chart
            } else {
                Text(loc(.anNoChartData))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(.vertical, 4)
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.day),
                    y: .value(metricLabel, point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(colors: [seriesColor.opacity(0.22), seriesColor.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value("Date", point.day),
                    y: .value(metricLabel, point.value)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(seriesColor)
            }
            if let last = points.last {
                PointMark(
                    x: .value("Date", last.day),
                    y: .value(metricLabel, last.value)
                )
                .foregroundStyle(seriesColor)
                .annotation(position: .topLeading, spacing: 4) {
                    Text(Fmt.number(last.value))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 160)
    }

    private var metricLabel: String {
        metric == .downloads ? loc(.rmDownloads) : loc(.anProceeds)
    }
}

// MARK: - Weekly metric comparison row (analytics)

/// A resolved weekly metric with its localized label, ready for `ForEach`.
struct WeekMetric: Identifiable {
    let label: String
    let metric: AnalyticsMetric
    var id: String { label }
}

extension WeekMetric {
    /// Extracts the weekly analytics metrics that actually carry a value from a mirrored
    /// `insights weekly` payload, in catalog order with localized labels.
    static func extract(from payloadJSON: String, loc: LocalizationManager) -> [WeekMetric] {
        let resolved = AnalyticsCatalog.resolve(MetricExtractor.extract(payloadJSON))
        let order: [LocKey] = [.anFirstDownloads, .anRedownloads, .anImpressions, .anPageViews,
                               .anConversion, .anProceeds, .anPayingUsers, .anIap,
                               .anActiveSubs, .anPaidSubs, .anMrr, .anRetention, .anCrashes]
        return order.compactMap { key in
            guard let metric = resolved[key], metric.value != nil else { return nil }
            return WeekMetric(label: loc(key), metric: metric)
        }
    }
}

/// One resolved weekly metric with its value and week-over-week delta chip.
/// Different metrics have different units, so this is deliberately a stat list,
/// not a shared-axis bar chart.
struct MetricCompareRow: View {
    let label: String
    let metric: AnalyticsMetric

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            if let value = metric.value {
                Text(Fmt.number(value, percent: metric.isPercentUnit))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            if let delta = metric.delta {
                DeltaBadge(delta: delta)
            }
        }
    }
}
