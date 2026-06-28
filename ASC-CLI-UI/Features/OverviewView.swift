import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
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
            // Keep the picker and the card in sync: adopt the app the card already shows so
            // there's a single source of truth (and so prefetch targets the visible app).
            if selectedApp == nil, let first = ascService.apps.first { selectedApp = first }
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

    private func select(_ app: ASCApp, _ section: SidebarItem) {
        selectedApp = app
        selectedSection = section
    }

    private func refreshAll() async {
        await ascService.loadApps()
        await ascService.loadCertificates()
        await ascService.loadProfiles()
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
