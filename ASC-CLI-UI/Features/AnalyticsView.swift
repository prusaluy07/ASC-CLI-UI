import SwiftUI
import Charts

// MARK: - Flexible JSON parsing

/// `asc insights` / `analytics compare` emit deterministic but differently-shaped JSON.
/// We decode into a generic value tree and extract numeric metrics defensively, so the
/// dashboard never crashes on schema variance and simply shows "not enough data" when a
/// metric is absent — mirroring App Store Connect's own behavior.
indirect enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool)
    case object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        self = .null
    }
}

struct AnalyticsMetric {
    let label: String
    let value: Double?       // nil when the metric is unavailable
    let delta: Double?       // percent change, if discoverable
    var unit: String? = nil
    var status: String? = nil
    var reason: String? = nil

    var isAvailable: Bool { value != nil }
    var isPercentUnit: Bool { (unit ?? "").lowercased().contains("percent") }
}

enum MetricExtractor {
    static func numeric(_ v: JSONValue?) -> Double? {
        switch v {
        case .number(let d): return d
        case .string(let s): return Double(s.replacingOccurrences(of: ",", with: ""))
        default: return nil
        }
    }
    static func string(_ v: JSONValue?) -> String? {
        if case .string(let s)? = v { return s }
        return nil
    }

    static func extract(_ output: String) -> [AnalyticsMetric] {
        guard let data = output.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [] }
        var out: [AnalyticsMetric] = []
        walk(root, inherited: nil, into: &out)
        // De-duplicate by normalized label, keeping the first occurrence.
        var seen = Set<String>()
        return out.filter { seen.insert(normalize($0.label)).inserted }
    }

    private static let valueKeys = ["value", "current", "total", "thisweek", "this_week", "count", "amount", "sum", "latest"]
    private static let prevKeys  = ["previous", "lastweek", "last_week", "prior", "baseline"]
    private static let pctKeys   = ["percentchange", "changepercent", "change_percent", "deltapercent", "pctchange", "percent_change"]

    private static func walk(_ v: JSONValue, inherited: String?, into out: inout [AnalyticsMetric]) {
        switch v {
        case .object(let o):
            let lower = Dictionary(uniqueKeysWithValues: o.map { ($0.key.lowercased(), $0.value) })
            let name = string(lower["name"]) ?? string(lower["label"]) ?? string(lower["metric"])
                ?? string(lower["title"]) ?? string(lower["key"])
            let label = name ?? inherited
            var val: Double?
            for k in valueKeys where val == nil { val = numeric(lower[k]) }
            var delta: Double?
            for k in pctKeys where delta == nil { delta = numeric(lower[k]) }
            if delta == nil {
                var prev: Double?
                for k in prevKeys where prev == nil { prev = numeric(lower[k]) }
                if let cur = val, let prev, prev != 0 { delta = (cur - prev) / abs(prev) * 100 }
            }
            let status = string(lower["status"])
            let reason = string(lower["reason"])
            // Treat an explicit named metric as one entry, even when its value is unavailable,
            // so we can surface the status/reason (e.g. "not permitted for the current API key").
            let isNamedMetric = name != nil && (val != nil || status != nil || reason != nil || lower["unit"] != nil)
            if isNamedMetric, let label {
                out.append(AnalyticsMetric(label: label, value: val, delta: delta,
                                           unit: string(lower["unit"]), status: status, reason: reason))
            } else {
                if let label, let val {
                    out.append(AnalyticsMetric(label: label, value: val, delta: delta))
                }
                // Flat numeric children become metrics keyed by their field name; recurse into the rest.
                for (k, child) in o {
                    if case .number(let d) = child {
                        out.append(AnalyticsMetric(label: k, value: d, delta: nil))
                    } else {
                        walk(child, inherited: k, into: &out)
                    }
                }
            }
        case .array(let a):
            for el in a { walk(el, inherited: inherited, into: &out) }
        default:
            break
        }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
}

// MARK: - Metric catalog

struct MetricSpec {
    let key: LocKey
    let synonyms: [String]
    var isPercent: Bool = false
    let group: Int   // 0 acquisition, 1 revenue, 2 subscriptions, 3 usage
}

enum AnalyticsCatalog {
    static let specs: [MetricSpec] = [
        // Acquisition
        .init(key: .anFirstDownloads, synonyms: ["firsttimedownload", "firstdownload", "newdownload", "installs"], group: 0),
        .init(key: .anRedownloads, synonyms: ["redownload", "repeatdownload"], group: 0),
        .init(key: .anConversion, synonyms: ["conversionrate", "conversion"], isPercent: true, group: 0),
        .init(key: .anImpressions, synonyms: ["impression"], group: 0),
        .init(key: .anPageViews, synonyms: ["productpageview", "pageview", "productpage"], group: 0),
        .init(key: .anUpdates, synonyms: ["update"], group: 0),
        // Revenue
        .init(key: .anProceeds, synonyms: ["proceeds", "developerproceeds", "erlose", "revenue"], group: 1),
        .init(key: .anPayingUsers, synonyms: ["payinguser", "payingaccount", "payer"], group: 1),
        .init(key: .anIap, synonyms: ["inapppurchase", "iap"], group: 1),
        // Subscriptions
        .init(key: .anActiveSubs, synonyms: ["activesubscription", "activesub"], group: 2),
        .init(key: .anPaidSubs, synonyms: ["paidsubscription", "paidsub"], group: 2),
        .init(key: .anMrr, synonyms: ["mrr", "monthlyrecurringrevenue", "recurringrevenue"], group: 2),
        // Usage
        .init(key: .anRetention, synonyms: ["retention"], isPercent: true, group: 3),
        .init(key: .anCrashes, synonyms: ["crash"], group: 3),
    ]

    /// Resolve catalog specs against extracted metrics.
    static func resolve(_ metrics: [AnalyticsMetric]) -> [LocKey: AnalyticsMetric] {
        var result: [LocKey: AnalyticsMetric] = [:]
        for spec in specs {
            let matches = metrics.filter { m in
                let n = MetricExtractor.normalize(m.label)
                return spec.synonyms.contains { n.contains($0) }
            }
            // Prefer a metric that actually has a value over an "unavailable" one.
            if let match = matches.first(where: { $0.value != nil }) ?? matches.first {
                result[spec.key] = match
            }
        }
        return result
    }
}

// MARK: - Number formatting

enum MetricFormat {
    static func value(_ v: Double, percent: Bool) -> String {
        if percent {
            let p = (v > 0 && v <= 1.0) ? v * 100 : v
            return String(format: "%.0f %%", p.rounded())
        }
        if v.truncatingRemainder(dividingBy: 1) == 0 && abs(v) < 1e15 {
            let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: v)) ?? String(Int(v))
        }
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }
}

// MARK: - Building blocks

private struct MetricCard: View {
    @EnvironmentObject var loc: LocalizationManager
    let title: String
    let metric: AnalyticsMetric?
    let isPercent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Image(systemName: "info.circle").font(.caption2).foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            if let metric, let value = metric.value {
                Text(MetricFormat.value(value, percent: isPercent || metric.isPercentUnit))
                    .font(.title2).fontWeight(.semibold).monospacedDigit()
                deltaBadge(metric.delta)
            } else {
                Text(loc(.anInsufficient)).font(.callout).foregroundStyle(.tertiary)
                    .padding(.top, 4)
                if let reason = metric?.reason, !reason.isEmpty {
                    Text(reason).font(.caption2).foregroundStyle(.tertiary).lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.12)))
    }

    @ViewBuilder
    private func deltaBadge(_ delta: Double?) -> some View {
        if let delta, delta.isFinite, delta != 0 {
            let up = delta > 0
            HStack(spacing: 2) {
                Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                Text(String(format: "%.0f %%", abs(delta)))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(up ? Color.green : Color.red)
        } else {
            Text("—").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

private struct ChartDatum: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private struct MetricBarChart: View {
    @EnvironmentObject var loc: LocalizationManager
    let title: String
    let icon: String
    let data: [ChartDatum]

    var body: some View {
        GroupBox {
            if data.isEmpty {
                Text(loc(.anNoChartData)).font(.callout).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(6)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Value", item.value),
                        y: .value("Metric", item.label)
                    )
                    .foregroundStyle(by: .value("Metric", item.label))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(MetricFormat.value(item.value, percent: false))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis { AxisMarks(preset: .aligned) }
                .frame(height: CGFloat(data.count) * 40 + 24)
                .padding(6)
            }
        } label: {
            Label(title, systemImage: icon)
        }
    }
}

// MARK: - Analytics dashboard

struct AnalyticsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var weekStart: Date = AnalyticsView.defaultWeekStart()
    @State private var resolved: [LocKey: AnalyticsMetric] = [:]
    @State private var revenue30: [LocKey: AnalyticsMetric] = [:]
    @State private var allMetrics: [AnalyticsMetric] = []
    @State private var rawText = ""
    @State private var isLoading = false
    @State private var loadedOnce = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.anTitle), subtitle: subtitleText) {
                Button {
                    Task { await load() }
                } label: {
                    if isLoading {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.anLoad)) }
                    } else {
                        Label(loc(.anLoad), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "chart.xyaxis.line",
                                       description: Text(loc(.selectAppFromApps)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        controls
                        if analyticsRestricted {
                            banner(loc(.anAnalyticsRestricted), icon: "exclamationmark.triangle", tint: .orange)
                        }
                        if ascService.vendorNumber.isEmpty {
                            banner(loc(.anNeedVendorSales), icon: "info.circle", tint: .blue)
                        }

                        group(loc(.anAcquisition), period: loc(.anWeekVsPrev), groupIndex: 0)
                        MetricBarChart(title: loc(.anChartAcq), icon: "chart.bar",
                                       data: chartData(for: [.anFirstDownloads, .anRedownloads, .anImpressions, .anPageViews, .anUpdates]))

                        group(loc(.anRevenue), period: loc(.anWeekVsPrev), groupIndex: 1)
                        MetricBarChart(title: loc(.anChartRev), icon: "dollarsign.circle",
                                       data: chartData(for: [.anProceeds, .anPayingUsers, .anIap]))

                        group(loc(.anSubscriptions), period: loc(.anWeekVsPrev), groupIndex: 2)
                        group(loc(.anUsage), period: loc(.anWeekVsPrev), groupIndex: 3)

                        if !revenue30.isEmpty { revenue30Section }

                        if !allMetrics.isEmpty {
                            DisclosureGroup(loc(.anAllMetrics)) { allMetricsList }
                                .font(.callout)
                        }
                        if !rawText.isEmpty {
                            DisclosureGroup(loc(.anRaw)) {
                                OutputPanel(title: loc(.output), text: rawText, maxHeight: 320)
                            }
                            .font(.callout)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: selectedApp?.id) {
            if selectedApp != nil && !loadedOnce { await load() }
        }
    }

    private var subtitleText: String? {
        guard let app = selectedApp else { return nil }
        return "\(app.name) · " + loc(.anWeekRangeFmt, Self.dateFmt.string(from: weekStart))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            DatePicker(loc(.anWeek), selection: $weekStart, displayedComponents: .date)
                .datePickerStyle(.field)
                .frame(maxWidth: 220)
            Spacer()
        }
    }

    private func group(_ title: String, period: String, groupIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3).fontWeight(.semibold)
                Text(period).font(.caption).foregroundStyle(.tertiary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 12)], spacing: 12) {
                ForEach(AnalyticsCatalog.specs.filter { $0.group == groupIndex }, id: \.key) { spec in
                    MetricCard(title: loc(spec.key), metric: resolved[spec.key], isPercent: spec.isPercent)
                }
            }
        }
    }

    private var revenue30Section: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(loc(.an30dRevenue)).font(.title3).fontWeight(.semibold)
                Text(loc(.an30dVsPrev)).font(.caption).foregroundStyle(.tertiary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 12)], spacing: 12) {
                ForEach(AnalyticsCatalog.specs.filter { $0.group == 1 || $0.group == 2 }, id: \.key) { spec in
                    if let m = revenue30[spec.key] {
                        MetricCard(title: loc(spec.key), metric: m, isPercent: spec.isPercent)
                    }
                }
            }
        }
    }

    private func chartData(for keys: [LocKey]) -> [ChartDatum] {
        keys.compactMap { key in
            guard let m = resolved[key], let v = m.value else { return nil }
            return ChartDatum(label: loc(key), value: v)
        }
    }

    private var analyticsRestricted: Bool {
        allMetrics.contains { ($0.reason ?? "").lowercased().contains("not permitted") }
    }

    private func banner(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption).foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private var allMetricsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(allMetrics.enumerated()), id: \.offset) { _, m in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.label).font(.system(.caption, design: .monospaced))
                        if let reason = m.reason, !reason.isEmpty {
                            Text(reason).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    if let v = m.value {
                        Text(MetricFormat.value(v, percent: m.isPercentUnit))
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    } else {
                        Text((m.status ?? loc(.anStatusUnavailable)))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(.top, 4)
    }

    private func load() async {
        guard let app = selectedApp else { return }
        isLoading = true
        loadedOnce = true
        let week = Self.dateFmt.string(from: weekStart)
        var raw = ""
        var collected: [AnalyticsMetric] = []

        let analytics = await ascService.insightsWeekly(appId: app.id, source: "analytics", week: week)
        raw += "$ asc insights weekly --source analytics --week \(week)\n"
            + (analytics.succeeded ? analytics.output : analytics.errorMessage) + "\n\n"
        collected += MetricExtractor.extract(analytics.output)

        if !ascService.vendorNumber.isEmpty {
            let sales = await ascService.insightsWeekly(appId: app.id, source: "sales", week: week)
            raw += "$ asc insights weekly --source sales --week \(week)\n"
                + (sales.succeeded ? sales.output : sales.errorMessage) + "\n\n"
            collected += MetricExtractor.extract(sales.output)

            // 30-day revenue comparison (last 30 days vs the previous 30).
            let cal = Calendar(identifier: .gregorian)
            let today = Date()
            func day(_ offset: Int) -> String {
                let date = cal.date(byAdding: .day, value: offset, to: today) ?? today
                return Self.dateFmt.string(from: date)
            }
            let compare = await ascService.analyticsCompareSales(
                appId: app.id, from: day(-60), fromEnd: day(-31), to: day(-30), toEnd: day(-1))
            raw += "$ asc analytics compare --source sales (30d)\n"
                + (compare.succeeded ? compare.output : compare.errorMessage) + "\n"
            revenue30 = AnalyticsCatalog.resolve(MetricExtractor.extract(compare.output))
        } else {
            revenue30 = [:]
        }

        resolved = AnalyticsCatalog.resolve(collected)
        allMetrics = collected
        rawText = raw
        isLoading = false
    }

    /// Monday of the last fully completed week.
    private static func defaultWeekStart() -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let now = Date()
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return cal.date(byAdding: .day, value: -7, to: thisWeek) ?? thisWeek
    }
}
