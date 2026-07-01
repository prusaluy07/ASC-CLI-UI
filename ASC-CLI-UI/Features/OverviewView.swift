import SwiftUI
import Charts
import ASCShared

struct OverviewView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var metricsEngine: MetricsEngine
    @Binding var selectedApp: ASCApp?
    @Binding var selectedSection: SidebarItem?
    @AppStorage(PrefetchSettings.enabledKey) private var prefetchEnabled = false

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.overviewTitle), subtitle: ascService.activeProfile) {
                Button {
                    Task { await refreshAll() }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading)
            }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ModeSelector()
                        .padding(.horizontal, 20)

                    if metricsEngine.recordCount > 0,
                       !metricsEngine.portfolio(apps: ascService.apps).filter({ $0.downloads > 0 || $0.proceeds > 0 }).isEmpty {
                        portfolioSection
                            .padding(.horizontal, 20)
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        StatCard(
                            title: loc(.statApps),
                            value: "\(ascService.apps.count)",
                            icon: "square.stack.3d.up",
                            tint: .blue
                        ) { selectedSection = .apps }
                        StatCard(
                            title: loc(.statCertificates),
                            value: "\(ascService.certificates.count)",
                            icon: "lock.shield",
                            tint: .purple
                        ) { selectedSection = .signing }
                        StatCard(
                            title: loc(.statProfiles),
                            value: "\(ascService.profiles.count)",
                            icon: "doc.badge.gearshape",
                            tint: .teal
                        ) { selectedSection = .signing }
                    }
                    .padding(.horizontal, 20)

                    fiscalCard
                        .padding(.horizontal, 20)

                    currentAppCard
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
        }
        .task {
            if ascService.apps.isEmpty { await ascService.loadApps() }
            if ascService.certificates.isEmpty { await ascService.loadCertificates() }
            if ascService.profiles.isEmpty { await ascService.loadProfiles() }
            if !ascService.reportsDirectory.isEmpty {
                _ = metricsEngine.scanDirectory(ascService.reportsDirectory, apps: ascService.apps)
            }
            if selectedApp == nil, let first = ascService.apps.first { selectedApp = first }
        }
    }

    private var portfolioSection: some View {
        let entries = metricsEngine.portfolio(apps: ascService.apps, days: 7)
            .filter { $0.downloads > 0 || $0.proceeds > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            Text(loc(.msPortfolioTitle)).font(.title3).fontWeight(.semibold)
            if entries.isEmpty {
                Text(loc(.msNoData)).font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(entries) { entry in
                        PortfolioMetricCard(entry: entry) {
                            if let app = ascService.apps.first(where: { $0.id == entry.appId }) {
                                selectedApp = app
                                selectedSection = .analytics
                            }
                        }
                    }
                }
            }
        }
    }

    private var fiscalCard: some View {
        GroupBox {
            if let period = AppleFiscalCalendar.period(),
               let payment = AppleFiscalCalendar.nextPayment() {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc(.ovFiscalPeriodFmt, period.fiscalYear, period.fiscalMonth))
                        .font(.callout.weight(.semibold))
                    Text(loc(.ovFiscalPaymentFmt, Self.displayDate(payment.paymentDate)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            } else {
                Text("—").font(.callout).foregroundStyle(.secondary).padding(6)
            }
        } label: {
            Label(loc(.ovFiscalTitle), systemImage: "calendar.badge.clock")
        }
    }

    @ViewBuilder
    private var currentAppCard: some View {
        GroupBox {
            if let app = selectedApp ?? ascService.apps.first {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Text(String(app.name.prefix(2)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(.tint)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).font(.title3).fontWeight(.semibold)
                            Text(app.bundleId).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            selectedSection = .apps
                        } label: {
                            Label(loc(.ovSwitchApp), systemImage: "rectangle.2.swap")
                        }
                        .help(loc(.ovSwitchAppHelp))
                    }

                    if metricsEngine.hasData(for: app) {
                        Divider()
                        appMetricsRow(for: app)
                    }

                    if !ascService.apps.isEmpty {
                        Divider()
                        Toggle(isOn: $prefetchEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc(.prefetchEnable)).font(.callout)
                                Text(loc(.prefetchEnableDesc)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        NavChip(title: loc(.secVersions), icon: "tag") { select(app, .versions) }
                        NavChip(title: loc(.secBuilds), icon: "hammer") { select(app, .builds) }
                        NavChip(title: loc(.secTestFlight), icon: "airplane") { select(app, .testflight) }
                        NavChip(title: loc(.secAnalytics), icon: "chart.xyaxis.line") { select(app, .analytics) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc(.noAppSelectedShort)).fontWeight(.medium)
                    Text(loc(.loadAppsPrompt))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(loc(.loadApps)) { Task { await ascService.loadApps() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
        } label: {
            Label(loc(.currentApp), systemImage: "app.dashed")
        }
    }

    private func appMetricsRow(for app: ASCApp) -> some View {
        let summary = metricsEngine.summary(for: app, days: 7)
        let subs = metricsEngine.subscriptionSummary(for: app, days: 30)
        return HStack(spacing: 16) {
            miniMetric(loc(.msDownloads7d), value: "\(summary.totalDownloads)", delta: nil)
            miniMetric(loc(.msProceeds7d), value: MetricFormat.value(summary.proceeds, percent: false), delta: nil)
            miniMetric(loc(.msSubscriptions30d), value: "\(subs.subscriptionUnits)", delta: nil)
            Spacer()
        }
    }

    private func miniMetric(_ title: String, value: String, delta: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            if let delta, delta != 0 {
                Text(String(format: "%+.0f%%", delta))
                    .font(.caption2)
                    .foregroundStyle(delta > 0 ? .green : .red)
            }
        }
    }

    private func select(_ app: ASCApp, _ section: SidebarItem) {
        selectedApp = app
        selectedSection = section
    }

    private func refreshAll() async {
        await ascService.loadApps()
        await ascService.loadCertificates()
        await ascService.loadProfiles()
        _ = metricsEngine.scanDirectory(ascService.reportsDirectory, apps: ascService.apps)
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static func displayDate(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }
}

struct PortfolioMetricCard: View {
    let entry: PortfolioMetricsEntry
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.appName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label("\(entry.downloads)", systemImage: "arrow.down.circle")
                        .font(.caption.monospacedDigit())
                    Label(MetricFormat.value(entry.proceeds, percent: false), systemImage: "dollarsign.circle")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                if let delta = entry.deltaDownloads {
                    Text(String(format: "%+.0f%%", delta))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(delta >= 0 ? .green : .red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct NavChip: View {
    let title: String
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
