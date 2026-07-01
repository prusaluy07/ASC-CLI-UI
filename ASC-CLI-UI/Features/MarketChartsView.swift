import SwiftUI
import ASCShared

struct MarketChartsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var market: MarketEngine
    @EnvironmentObject var ascService: ASCService

    @State private var selectedEntry: AppStoreChartEntry?

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secMarketCharts), subtitle: market.country.uppercased()) {
                Button { Task { await market.refreshCharts() } } label: {
                    Label(loc(.mktRefresh), systemImage: "arrow.clockwise")
                }
                .disabled(market.isLoading)
            }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.mktChartsBody)).font(.callout).foregroundStyle(.secondary)

                    controls

                    if let index = market.marketIndex {
                        marketIndexCard(index)
                    }

                    ownAppsSection

                    if market.isLoading, market.feed == nil {
                        ProgressView(loc(.mktLoading)).frame(maxWidth: .infinity)
                    } else if let feed = market.feed {
                        chartList(feed)
                    } else if let err = market.lastError {
                        ContentUnavailableView(loc(.mktError), systemImage: "wifi.exclamationmark",
                                               description: Text(err))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { await market.refreshCharts() }
        .sheet(item: $selectedEntry) { entry in
            ChartAppDetailSheet(entry: entry, country: market.country)
                .environmentObject(loc)
                .environmentObject(market)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker(loc(.mktCountry), selection: Binding(
                get: { market.country },
                set: { market.setCountry($0) }
            )) {
                ForEach(MarketEngine.supportedCountries, id: \.code) { c in
                    Text(c.label).tag(c.code)
                }
            }
            .frame(width: 180)

            Picker("", selection: $market.category) {
                ForEach(AppStoreChartCategory.allCases) { cat in
                    Text(loc(cat.locKey)).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("", selection: $market.chartKind) {
                ForEach(AppStoreChartKind.allCases) { kind in
                    Text(loc(kind.locKey)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .onChange(of: market.category) { _, _ in Task { await market.refreshCharts() } }
        .onChange(of: market.chartKind) { _, _ in Task { await market.refreshCharts() } }
        .onChange(of: market.country) { _, _ in Task { await market.refreshCharts() } }
    }

    private func marketIndexCard(_ index: MarketIndexResult) -> some View {
        let title: String = switch index.direction {
        case "up": loc(.mktMarketIndexUp)
        case "down": loc(.mktMarketIndexDown)
        default: loc(.mktMarketIndexFlat)
        }
        return GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title3).fontWeight(.semibold)
                Text(loc(.mktMarketIndexFmt, title,
                         index.upwardMoves, index.downwardMoves, index.newEntrants))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Label(loc(.mktMarketIndexTitle), systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private var ownAppsSection: some View {
        let matches = ascService.apps.compactMap { app -> (ASCApp, AppStoreChartEntry)? in
            guard let entry = market.chartRank(forAppleId: app.id) else { return nil }
            return (app, entry)
        }
        return Group {
            if !matches.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(matches, id: \.0.id) { app, entry in
                            HStack {
                                Text(app.name).fontWeight(.medium)
                                Spacer()
                                Text(loc(.mktRankFmt, entry.rank))
                                    .foregroundStyle(.secondary)
                                if let delta = market.rankDelta(forAppleId: app.id) {
                                    Text(loc(.mktRankDeltaFmt, delta))
                                        .font(.caption)
                                        .foregroundStyle(delta >= 0 ? .green : .red)
                                }
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label(loc(.mktCompareOwnApps), systemImage: "star.circle")
                }
            }
        }
    }

    private func chartList(_ feed: AppStoreChartsFeed) -> some View {
        GroupBox {
            LazyVStack(spacing: 0) {
                ForEach(feed.entries) { entry in
                    ChartEntryRow(
                        entry: entry,
                        bookmarked: market.isBookmarked(entry.id),
                        onBookmark: { market.toggleBookmark(entry.id) },
                        onSelect: { selectedEntry = entry }
                    )
                    if entry.id != feed.entries.last?.id { Divider() }
                }
            }
            .padding(4)
        } label: {
            Label("\(loc(feed.kind.locKey)) · \(loc(feed.category.locKey))", systemImage: "list.number")
        }
    }
}

// MARK: - Row

private struct ChartEntryRow: View {
    @EnvironmentObject var loc: LocalizationManager
    let entry: AppStoreChartEntry
    let bookmarked: Bool
    let onBookmark: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(loc(.mktRankFmt, entry.rank))
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
                if let url = entry.artworkURL, let artURL = URL(string: url) {
                    AsyncImage(url: artURL) { phase in
                        if let img = phase.image { img.resizable().scaledToFit() }
                        else { Color.secondary.opacity(0.15) }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).fontWeight(.medium).lineLimit(1)
                    Text(entry.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button(action: onBookmark) {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.plain)
                .help(loc(bookmarked ? .mktBookmarked : .mktBookmark))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail sheet

struct ChartAppDetailSheet: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let entry: AppStoreChartEntry
    let country: String

    @State private var detail: ITunesAppResult?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if let detail {
                    ITunesAppDetailView(app: detail)
                } else if isLoading {
                    ProgressView(loc(.mktLoading))
                } else {
                    ContentUnavailableView(loc(.mktError), systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle(entry.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc(.close)) { dismiss() }
                }
                if let url = entry.storeURL, let storeURL = URL(string: url) {
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: storeURL) {
                            Label(loc(.mktOpenStore), systemImage: "arrow.up.forward.app")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 520)
        .task { await loadDetail() }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        if let id = Int64(entry.id) {
            detail = try? await ITunesSearchClient.lookup(id: id, country: country)
        }
    }
}
