import SwiftUI
import ASCShared

enum SidebarSection: String, CaseIterable, Identifiable {
    case app, monetization, build, release, ads, developer

    var id: String { rawValue }

    var locKey: LocKey {
        switch self {
        case .app:          return .grpApp
        case .monetization: return .grpMonetization
        case .build:        return .grpBuild
        case .release:      return .grpRelease
        case .ads:          return .grpAds
        case .developer:    return .grpDeveloper
        }
    }

    var items: [SidebarItem] {
        switch self {
        case .app:          return [.overview, .analytics, .apps, .versions, .metadata, .media, .pricing, .reviews, .marketing]
        case .monetization: return [.subscriptions, .iap, .appEvents]
        case .build:        return [.builds, .testflight, .xcodeCloud]
        case .release:      return [.release, .submission, .compliance, .reports, .workflows]
        case .ads:          return [.ads]
        case .developer:    return [.signing, .distribution, .team, .tools, .discover, .terminal, .help]
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, analytics, apps, versions, metadata, media, pricing, reviews, marketing
    case subscriptions, iap, appEvents
    case builds, testflight, xcodeCloud
    case release, submission, compliance, reports, workflows
    case ads, distribution
    case signing, team, tools, discover, terminal, help

    var id: String { rawValue }

    var locKey: LocKey {
        switch self {
        case .overview:   return .secOverview
        case .analytics:  return .secAnalytics
        case .apps:       return .secApps
        case .versions:   return .secVersions
        case .metadata:   return .secMetadata
        case .media:      return .secMedia
        case .pricing:    return .secPricing
        case .reviews:    return .secReviews
        case .marketing:  return .secMarketing
        case .subscriptions: return .secSubscriptions
        case .iap:        return .secIAP
        case .appEvents:  return .secAppEvents
        case .builds:     return .secBuilds
        case .testflight: return .secTestFlight
        case .xcodeCloud: return .secXcodeCloud
        case .release:    return .secRelease
        case .submission: return .secSubmission
        case .compliance: return .secCompliance
        case .reports:    return .secReports
        case .workflows:  return .secWorkflows
        case .ads:        return .secAds
        case .distribution: return .secDistribution
        case .signing:    return .secSigning
        case .team:       return .secTeam
        case .tools:      return .secTools
        case .discover:   return .secDiscover
        case .terminal:   return .secTerminal
        case .help:       return .secHelp
        }
    }

    var icon: String {
        switch self {
        case .overview:   return "square.grid.2x2"
        case .analytics:  return "chart.xyaxis.line"
        case .apps:       return "square.stack.3d.up"
        case .versions:   return "tag"
        case .metadata:   return "doc.text"
        case .media:      return "photo.on.rectangle"
        case .pricing:    return "dollarsign.circle"
        case .reviews:    return "star.bubble"
        case .marketing:  return "megaphone.fill"
        case .subscriptions: return "repeat.circle"
        case .iap:        return "cart"
        case .appEvents:  return "calendar"
        case .builds:     return "hammer"
        case .testflight: return "airplane"
        case .xcodeCloud: return "cloud"
        case .release:    return "shippingbox"
        case .submission: return "paperplane"
        case .compliance: return "checklist"
        case .reports:    return "chart.bar"
        case .workflows:  return "arrow.triangle.branch"
        case .ads:        return "megaphone"
        case .distribution: return "globe"
        case .signing:    return "lock.shield"
        case .team:       return "person.2"
        case .tools:      return "wrench.and.screwdriver"
        case .discover:   return "magnifyingglass"
        case .terminal:   return "terminal"
        case .help:       return "questionmark.circle"
        }
    }

    /// Sections that operate on a specific app.
    var requiresApp: Bool {
        switch self {
        case .analytics, .versions, .metadata, .media, .builds, .testflight, .xcodeCloud, .release,
             .pricing, .reviews, .subscriptions, .iap, .appEvents, .submission, .compliance: return true
        default: return false
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage("asc.hasOnboarded") private var hasOnboarded = false
    @AppStorage(PrefetchSettings.enabledKey) private var prefetchEnabled = false
    @AppStorage(PrefetchSettings.sectionsKey) private var prefetchSectionsRaw = PrefetchSettings.defaultRaw

    @State private var selectedItem: SidebarItem? = .overview
    @State private var selectedApp: ASCApp?
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedApp) { _, newApp in
            triggerPrefetch(for: newApp)
        }
        .onChange(of: prefetchEnabled) { _, enabled in
            // Turning prefetch on should warm the already-selected app immediately.
            if enabled { triggerPrefetch(for: selectedApp) }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(ascService)
                .environmentObject(loc)
        }
        .sheet(isPresented: Binding(
            get: { !hasOnboarded },
            set: { presented in if !presented { hasOnboarded = true } }
        )) {
            OnboardingView {
                hasOnboarded = true
            }
            .environmentObject(ascService)
            .environmentObject(loc)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if ascService.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                appPicker
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(loc(.settingsTitle))
            }
        }
        .alert("⚠︎", isPresented: Binding(
            get: { ascService.lastError != nil },
            set: { if !$0 { ascService.lastError = nil } }
        )) {
            Button(loc(.ok)) { ascService.lastError = nil }
        } message: {
            Text(ascService.lastError ?? "")
        }
    }

    private func triggerPrefetch(for app: ASCApp?) {
        guard prefetchEnabled, let app else { return }
        let sections = PrefetchSettings.decode(prefetchSectionsRaw)
        guard !sections.isEmpty else { return }
        Task { await ascService.prefetch(appId: app.id, sections: sections) }
    }

    // MARK: - App picker (shared selection)

    @ViewBuilder
    private var appPicker: some View {
        if !ascService.apps.isEmpty {
            Picker("App", selection: $selectedApp) {
                Text(loc(.noAppSelectedShort)).tag(ASCApp?.none)
                ForEach(ascService.apps) { app in
                    Text(app.name).tag(ASCApp?.some(app))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 220)
            .help(loc(.activeAppHelp))
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedItem) {
            ForEach(SidebarSection.allCases) { section in
                Section(loc(section.locKey)) {
                    ForEach(section.items) { item in
                        Label(loc(item.locKey), systemImage: item.icon)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(loc(.appName))
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .safeAreaInset(edge: .bottom) {
            configurationStatus
        }
    }

    private var configurationStatus: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(ascService.isConfigured ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ascService.isConfigured ? loc(.connected) : loc(.notConfigured))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    if let profile = ascService.activeProfile, ascService.isConfigured {
                        Text(profile)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if selectedItem == .help {
            HelpView()
        } else if !ascService.isConfigured {
            NotConfiguredView { showSettings = true }
        } else if let item = selectedItem {
            switch item {
            case .overview:
                OverviewView(selectedApp: $selectedApp, selectedSection: $selectedItem)
            case .analytics:
                AnalyticsView(selectedApp: selectedApp)
            case .apps:
                AppsView(selectedApp: $selectedApp)
            case .versions:
                VersionsView(selectedApp: selectedApp)
            case .metadata:
                MetadataView(selectedApp: selectedApp)
            case .media:
                MediaView(selectedApp: selectedApp)
            case .pricing:
                PricingView(selectedApp: selectedApp)
            case .reviews:
                ReviewsView(selectedApp: selectedApp)
            case .marketing:
                MarketingView(selectedApp: selectedApp)
            case .subscriptions:
                SubscriptionsView(selectedApp: selectedApp)
            case .iap:
                IAPView(selectedApp: selectedApp)
            case .appEvents:
                AppEventsView(selectedApp: selectedApp)
            case .builds:
                BuildsView(selectedApp: selectedApp)
            case .testflight:
                TestFlightView(selectedApp: selectedApp)
            case .xcodeCloud:
                XcodeCloudView(selectedApp: selectedApp)
            case .release:
                ReleaseView(selectedApp: selectedApp)
            case .submission:
                SubmissionView(selectedApp: selectedApp)
            case .compliance:
                ComplianceView(selectedApp: selectedApp)
            case .reports:
                ReportsView(selectedApp: selectedApp)
            case .workflows:
                WorkflowsView()
            case .ads:
                AdsView()
            case .distribution:
                DistributionView(selectedApp: selectedApp)
            case .signing:
                SigningView()
            case .team:
                TeamView()
            case .tools:
                ToolsView(selectedApp: selectedApp)
            case .discover:
                DiscoverView()
            case .terminal:
                TerminalView()
            case .help:
                HelpView()
            }
        } else {
            ContentUnavailableView(loc(.selectSection), systemImage: "sidebar.left")
        }
    }
}

// MARK: - Not Configured

struct NotConfiguredView: View {
    @EnvironmentObject var loc: LocalizationManager
    var openSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(loc(.notConfiguredTitle))
                .font(.title2)
                .fontWeight(.semibold)
            Text(loc(.notConfiguredDesc))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(loc(.openSettings), action: openSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
