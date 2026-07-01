import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers
import ASCShared

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
    @EnvironmentObject var metricsEngine: MetricsEngine
    let selectedApp: ASCApp?

    @AppStorage(AppModeSettings.key) private var appMode = AppMode.online
    @State private var weekStart: Date = AnalyticsView.defaultWeekStart()
    @State private var resolved: [LocKey: AnalyticsMetric] = [:]
    @State private var revenue30: [LocKey: AnalyticsMetric] = [:]
    @State private var allMetrics: [AnalyticsMetric] = []
    @State private var rawText = ""
    @State private var isLoading = false
    @State private var loadedOnce = false

    // App Store Analytics API report pipeline (requests → view → download → parse).
    @State private var isLoadingReport = false
    @State private var reportStatus: String?
    @State private var reportInstances: [AnalyticsInstanceRef] = []
    @State private var reportRaw = ""
    /// Set when an analytics API call is rejected because the key lacks the Admin/Account
    /// Holder role, so we can surface the "assign an Admin profile" guidance.
    @State private var reportForbidden = false

    // Locally stored sales-report metrics (primary when available).
    @State private var storedWeek: [LocKey: AnalyticsMetric] = [:]
    @State private var stored30: [LocKey: AnalyticsMetric] = [:]
    @State private var storedTrend: [MetricsTrendPoint] = []
    @State private var trendSeries: StoredTrendSeries = .downloads

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    private static let fiscalDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
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
                        if let app = selectedApp, metricsEngine.hasData(for: app) {
                            storedMetricsSection(for: app)
                        }
                        if analyticsRestricted || reportForbidden {
                            permissionBanner
                        }
                        if analyticsRestricted {
                            banner(loc(.anAnalyticsRestricted), icon: "info.circle", tint: .blue)
                        }
                        if analyticsNeedsRequest {
                            requestBanner
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

                        if showRevenue30Section { revenue30Section }

                        reportSection

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
            refreshStoredMetrics()
            if selectedApp != nil && !loadedOnce && appMode == .online { await load() }
            if !ascService.reportsDirectory.isEmpty {
                _ = metricsEngine.scanDirectory(ascService.reportsDirectory, apps: ascService.apps)
                refreshStoredMetrics()
            }
        }
        .onChange(of: metricsEngine.recordCount) { _, _ in refreshStoredMetrics() }
    }

    private enum StoredTrendSeries: String, CaseIterable, Identifiable {
        case downloads, proceeds, iap, updates, returns
        var id: String { rawValue }
    }

    private func refreshStoredMetrics() {
        guard let app = selectedApp, metricsEngine.hasData(for: app) else {
            storedWeek = [:]
            stored30 = [:]
            storedTrend = []
            return
        }
        storedWeek = metricsEngine.weekMetrics(for: app)
        stored30 = metricsEngine.monthMetrics(for: app)
        storedTrend = metricsEngine.trend(for: app, days: 30)
    }

    private func displayMetric(_ key: LocKey) -> AnalyticsMetric? {
        if let app = selectedApp, metricsEngine.hasData(for: app), let stored = storedWeek[key], stored.isAvailable {
            return stored
        }
        return resolved[key]
    }

    private func display30Metric(_ key: LocKey) -> AnalyticsMetric? {
        if let app = selectedApp, metricsEngine.hasData(for: app), let stored = stored30[key], stored.isAvailable {
            return stored
        }
        return revenue30[key]
    }

    private var usesStoredPrimary: Bool {
        guard let app = selectedApp else { return false }
        return metricsEngine.hasData(for: app)
    }

    private func storedMetricsSection(for app: ASCApp) -> some View {
        let subs = metricsEngine.subscriptionSummary(for: app, days: 30)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(loc(.msTitle)).font(.title3).fontWeight(.semibold)
                Text(loc(.msFromReports)).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button { exportMetrics(app, format: .csv) } label: {
                    Label(loc(.exportCSV), systemImage: "square.and.arrow.up")
                }
                Button { exportMetrics(app, format: .json) } label: {
                    Label(loc(.exportJSON), systemImage: "curlybraces")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 12)], spacing: 12) {
                if let m = storedWeek[.anFirstDownloads] {
                    MetricCard(title: loc(.msDownloads7d), metric: m, isPercent: false)
                }
                if let m = storedWeek[.anProceeds] {
                    MetricCard(title: loc(.msProceeds7d), metric: m, isPercent: false)
                }
                if let m = storedWeek[.anReturns] {
                    MetricCard(title: loc(.anReturns), metric: m, isPercent: false)
                }
                MetricCard(title: loc(.msSubscriptions30d),
                           metric: AnalyticsMetric(label: "", value: Double(subs.subscriptionUnits), delta: nil),
                           isPercent: false)
                if let payment = AppleFiscalCalendar.nextPayment() {
                    let dateText = Self.fiscalDateFormatter.string(from: payment.paymentDate)
                    MetricCard(title: loc(.msNextPayout),
                               metric: AnalyticsMetric(label: "", value: nil, delta: nil, reason: dateText),
                               isPercent: false)
                }
            }
            if !storedTrend.isEmpty {
                GroupBox {
                    Picker("", selection: $trendSeries) {
                        Text(loc(.anFirstDownloads)).tag(StoredTrendSeries.downloads)
                        Text(loc(.anProceeds)).tag(StoredTrendSeries.proceeds)
                        Text(loc(.anIap)).tag(StoredTrendSeries.iap)
                        Text(loc(.anUpdates)).tag(StoredTrendSeries.updates)
                        Text(loc(.anReturns)).tag(StoredTrendSeries.returns)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Chart(storedTrend) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", trendValue(point))
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 160)
                    .padding(6)
                } label: {
                    Label(loc(.msTrendTitle), systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }

    private func trendValue(_ point: MetricsTrendPoint) -> Double {
        switch trendSeries {
        case .downloads: return Double(point.downloads)
        case .proceeds: return point.proceeds
        case .iap: return Double(point.iapUnits)
        case .updates: return Double(point.updates)
        case .returns: return Double(point.returns)
        }
    }

    private enum ExportFormat { case csv, json }

    private func exportMetrics(_ app: ASCApp, format: ExportFormat) {
        let text = format == .csv ? metricsEngine.exportCSV(for: app) : metricsEngine.exportJSON(for: app)
        let panel = NSSavePanel()
        panel.allowedContentTypes = format == .csv ? [.commaSeparatedText] : [.json]
        panel.nameFieldStringValue = "\(app.name)-metrics.\(format == .csv ? "csv" : "json")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private var subtitleText: String? {
        guard let app = selectedApp else { return nil }
        return "\(app.name) · " + loc(.anWeekRangeFmt, Self.dateFmt.string(from: weekMonday))
    }

    /// The Monday of the week containing `weekStart`. App Store Connect weekly reports must
    /// be addressed by a week that ends on a Sunday (i.e. starts on a Monday); passing any
    /// other weekday makes the sales source fail with "Invalid date. … specify the date of
    /// the Sunday ending the desired week." Normalizing here lets the date picker stay free.
    private var weekMonday: Date {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        return cal.dateInterval(of: .weekOfYear, for: weekStart)?.start ?? weekStart
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
                    MetricCard(title: loc(spec.key), metric: displayMetric(spec.key), isPercent: spec.isPercent)
                }
            }
        }
    }

    private var revenue30Section: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(loc(.an30dRevenue)).font(.title3).fontWeight(.semibold)
                Text(usesStoredPrimary ? loc(.msFromReports) : loc(.an30dVsPrev))
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 12)], spacing: 12) {
                ForEach(AnalyticsCatalog.specs.filter { $0.group == 1 || $0.group == 2 }, id: \.key) { spec in
                    if let m = display30Metric(spec.key) {
                        MetricCard(title: loc(spec.key), metric: m, isPercent: spec.isPercent)
                    }
                }
            }
        }
    }

    private var showRevenue30Section: Bool {
        usesStoredPrimary || !revenue30.isEmpty
    }

    private func chartData(for keys: [LocKey]) -> [ChartDatum] {
        keys.compactMap { key in
            guard let m = displayMetric(key), let v = m.value else { return nil }
            return ChartDatum(label: loc(key), value: v)
        }
    }

    private var analyticsRestricted: Bool {
        allMetrics.contains { ($0.reason ?? "").lowercased().contains("not permitted") }
    }

    /// True when the analytics source works but no report requests have been created yet
    /// (Apple returns "no completed analytics report requests found"). Distinct from
    /// `analyticsRestricted`, which means the key lacks analytics permission entirely.
    private var analyticsNeedsRequest: Bool {
        !analyticsRestricted &&
        allMetrics.contains { ($0.reason ?? "").lowercased().contains("no completed analytics report requests") }
    }

    private var requestBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(loc(.anNeedRequest), systemImage: "clock.arrow.circlepath")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                Task { await requestAnalytics() }
            } label: {
                Label(loc(.rpCreateRequest), systemImage: "plus.rectangle.on.folder")
            }
            .controlSize(.small)
            .disabled(isLoading || selectedApp == nil)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Creates the one-time ONGOING analytics report request, then reloads so the new
    /// request shows up in the raw output (metrics still take ~1–2 days to populate).
    private func requestAnalytics() async {
        guard let app = selectedApp else { return }
        isLoading = true
        let result = await ascService.createAnalyticsRequest(appId: app.id)
        isLoading = false
        rawText = "$ asc analytics request --access-type ONGOING\n"
            + (result.succeeded ? result.output : result.errorMessage) + "\n\n" + rawText
    }

    // MARK: - App Store Analytics API report pipeline

    private var reportSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc(.anReportBody)).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    Button {
                        Task { await loadReportData() }
                    } label: {
                        if isLoadingReport {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.anReportLoad)) }
                        } else {
                            Label(loc(.anReportLoad), systemImage: "arrow.down.doc")
                        }
                    }
                    .disabled(isLoadingReport || selectedApp == nil)

                    Button {
                        Task { await createReportRequests() }
                    } label: {
                        Label(loc(.anReportCreate), systemImage: "plus.rectangle.on.folder")
                    }
                    .disabled(isLoadingReport || selectedApp == nil)
                    Spacer()
                }
                if let reportStatus {
                    Label(reportStatus, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !reportInstances.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(reportInstances.prefix(6)) { inst in
                            Text("• \(inst.reportName ?? inst.instanceId) · \(inst.granularity ?? "—") · \(inst.processingDate ?? "—")")
                                .font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
                if !reportRaw.isEmpty {
                    DisclosureGroup(loc(.anRaw)) {
                        OutputPanel(title: loc(.output), text: reportRaw, maxHeight: 280)
                    }
                    .font(.callout)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.anReportTitle), systemImage: "chart.bar.doc.horizontal")
        }
    }

    /// Creates both the one-time-snapshot (historical) and ongoing analytics report requests.
    private func createReportRequests() async {
        guard let app = selectedApp else { return }
        isLoadingReport = true
        defer { isLoadingReport = false }
        let snapshot = await ascService.createAnalyticsRequest(appId: app.id, accessType: "ONE_TIME_SNAPSHOT")
        let ongoing = await ascService.createAnalyticsRequest(appId: app.id, accessType: "ONGOING")
        reportRaw = "$ asc analytics request --access-type ONE_TIME_SNAPSHOT\n" + outText(snapshot) + "\n\n"
            + "$ asc analytics request --access-type ONGOING\n" + outText(ongoing) + "\n\n" + reportRaw
        if snapshot.succeeded || ongoing.succeeded {
            reportStatus = loc(.anReportCreated)
            reportForbidden = false
        } else if isForbidden(snapshot) || isForbidden(ongoing) {
            reportStatus = loc(.anReportForbidden)
            reportForbidden = true
        } else {
            reportStatus = snapshot.errorMessage
        }
    }

    /// Runs the full report pipeline: list requests → view instances for the week →
    /// download the newest instance → parse it → merge the metrics into the cards.
    private func loadReportData() async {
        guard let app = selectedApp else { return }
        isLoadingReport = true
        defer { isLoadingReport = false }
        reportRaw = ""
        reportInstances = []
        reportForbidden = false

        let requests = await ascService.analyticsRequests(appId: app.id)
        reportRaw += "$ asc analytics requests\n" + outText(requests) + "\n\n"
        guard requests.succeeded else {
            reportForbidden = isForbidden(requests)
            reportStatus = reportForbidden ? loc(.anReportForbidden) : requests.errorMessage
            return
        }
        guard let requestId = Self.firstRequestId(requests.output) else {
            reportStatus = loc(.anNeedRequest)
            return
        }

        let date = Self.dateFmt.string(from: weekMonday)
        let view = await ascService.analyticsViewReports(requestId: requestId, date: date)
        reportRaw += "$ asc analytics view --request-id \(requestId) --date \(date)\n" + outText(view) + "\n\n"
        guard view.succeeded else {
            reportForbidden = isForbidden(view)
            reportStatus = reportForbidden ? loc(.anReportForbidden) : view.errorMessage
            return
        }

        let instances = AnalyticsReportLocator.instances(fromViewJSON: view.output)
        reportInstances = instances
        guard let instance = instances.first else {
            reportStatus = loc(.anReportProcessing)
            return
        }

        let download = await ascService.analyticsDownloadReport(
            requestId: requestId, instanceId: instance.instanceId, segmentId: instance.segmentIds.first)
        reportRaw += "$ asc analytics download --instance-id \(instance.instanceId)\n" + outText(download.result) + "\n\n"
        guard let csv = download.text, !csv.isEmpty else {
            reportForbidden = isForbidden(download.result)
            reportStatus = reportForbidden ? loc(.anReportForbidden) : download.result.errorMessage
            return
        }

        let table = AnalyticsReportTable(text: csv)
        let metrics = AnalyticsReportSummarizer.metrics(from: table)
        reportRaw += "Columns: \(table.columns.joined(separator: ", "))\nRows: \(table.rows.count)\n"

        let resolvedFromReport = AnalyticsCatalog.resolve(metrics)
        for (key, metric) in resolvedFromReport where metric.value != nil {
            resolved[key] = metric
        }
        deriveConversionIfPossible()
        allMetrics += metrics
        reportStatus = loc(.anReportLoadedFmt, table.rows.count, instance.reportName ?? instance.instanceId)
    }

    /// Derives a conversion-rate card from impressions + downloads when the report didn't
    /// provide one directly (downloads ÷ impressions × 100).
    private func deriveConversionIfPossible() {
        guard resolved[.anConversion]?.value == nil,
              let impressions = resolved[.anImpressions]?.value, impressions > 0 else { return }
        let downloads = (resolved[.anFirstDownloads]?.value ?? 0) + (resolved[.anRedownloads]?.value ?? 0)
        guard downloads > 0 else { return }
        resolved[.anConversion] = AnalyticsMetric(
            label: loc(.anConversion), value: downloads / impressions * 100, delta: nil, unit: "percent")
    }

    private func outText(_ result: CommandResult) -> String {
        result.succeeded ? result.output : result.errorMessage
    }

    private func isForbidden(_ result: CommandResult) -> Bool {
        let m = result.errorMessage.lowercased()
        return m.contains("does not allow this request") || m.contains("forbidden")
    }

    /// Picks a request id from `asc analytics requests` JSON, preferring an ONGOING request.
    private static func firstRequestId(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = object["data"] as? [[String: Any]], !array.isEmpty else { return nil }
        if let ongoing = array.first(where: {
            (($0["attributes"] as? [String: Any])?["accessType"] as? String) == "ONGOING"
        }), let id = ongoing["id"] as? String {
            return id
        }
        return array.first?["id"] as? String
    }

    /// The credential profile App Analytics calls currently route through (the dedicated
    /// `.analytics` mapping, or the active profile as a fallback).
    private var analyticsProfileLabel: String {
        ascService.profileFor(.analytics) ?? loc(.defaultTag)
    }

    /// Actionable guidance shown when analytics is blocked by API-key permissions: explains the
    /// Admin/Account Holder requirement, names the profile in use, and deep-links to Settings.
    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(loc(.anAdminRequiredTitle), systemImage: "lock.shield")
                .font(.callout.weight(.semibold))
            Text(loc(.anAdminRequiredBody))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(loc(.anAnalyticsUsingProfileFmt, analyticsProfileLabel))
                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
            Button {
                NotificationCenter.default.post(name: .ascOpenProfileSettings, object: nil)
            } label: {
                Label(loc(.anOpenProfileSettings), systemImage: "key")
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.25)))
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
        reportForbidden = false
        let week = Self.dateFmt.string(from: weekMonday)
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
