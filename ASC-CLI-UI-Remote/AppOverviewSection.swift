import SwiftUI
import ASCShared

/// Overview header for a mirrored app: headline tiles assembled from the section
/// summaries the producer already computed, a 14-day sales trend chart when
/// `storedMetrics` is mirrored, and a week-over-week metric list when `analytics` is.
/// Renders nothing it has no data for — apps mirroring only a section or two just
/// get a smaller header.
struct AppOverviewSection: View {
    @EnvironmentObject private var loc: LocalizationManager
    let group: MirrorAppGroup

    var body: some View {
        if !tiles.isEmpty || storedMetrics != nil {
            Section(loc(.secOverview)) {
                if !tiles.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(tiles) { tile in
                            StatTile(title: tile.title, value: tile.value,
                                     caption: tile.caption, systemImage: tile.icon)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }
                if let storedMetrics {
                    TrendChartCard(payload: storedMetrics)
                }
            }
        }
        if !weekMetrics.isEmpty {
            Section(loc(.rmWeekCompare)) {
                ForEach(weekMetrics) { entry in
                    MetricCompareRow(label: entry.label, metric: entry.metric)
                }
            }
        }
    }

    // MARK: Data assembly

    private struct Tile: Identifiable {
        let id: String
        let title: String
        let value: String
        var caption: String? = nil
        var icon: String? = nil
    }

    private func summary(_ section: MirrorSection) -> [String: String] {
        group.snapshots[section]?.summary ?? [:]
    }

    private var storedMetrics: StoredMetricsPayload? {
        group.snapshots[.storedMetrics].flatMap { StoredMetricsPayload.decode($0.payloadJSON) }
    }

    private var tiles: [Tile] {
        var out: [Tile] = []

        let status = summary(.status)
        if let health = status["health"] {
            out.append(Tile(id: "health", title: loc(.relHealth),
                            value: Fmt.prettyToken(health),
                            caption: status["nextAction"], icon: "checkmark.seal"))
        }

        let versions = summary(.versions)
        if let version = versions["latestVersion"] {
            out.append(Tile(id: "version", title: loc(.rmLatestVersion), value: version,
                            caption: versions["latestState"].map(Fmt.prettyToken), icon: "number"))
        }

        let builds = summary(.builds)
        if let build = builds["latestBuild"] ?? status["latestBuild"] {
            out.append(Tile(id: "build", title: loc(.rmLatestBuild), value: build,
                            caption: builds["latestState"].map(Fmt.prettyToken), icon: "hammer"))
        }

        let reviews = summary(.reviews)
        if let average = reviews["averageRating"] {
            let caption = reviews["ratingCount"]
                .flatMap(Int.init)
                .map { loc(.rmRatingsCountFmt, $0) }
            out.append(Tile(id: "rating", title: loc(.rmRating), value: "★ \(average)",
                            caption: caption, icon: "star"))
        }

        if let rank = group.snapshots[.marketRank].flatMap({ MarketRankPayload.decode($0.payloadJSON) }) {
            var value = "#\(rank.rank)"
            if let delta = rank.delta, delta != 0 {
                // Negative delta = climbed the chart (smaller rank number).
                value += delta < 0 ? " ↑\(abs(delta))" : " ↓\(delta)"
            }
            out.append(Tile(id: "rank", title: loc(.rmRank), value: value,
                            caption: "\(rank.chart) · \(rank.country.uppercased())",
                            icon: "chart.bar"))
        }

        if let metrics = storedMetrics {
            out.append(Tile(id: "downloads7d", title: loc(.rmDownloads7d),
                            value: Fmt.integer(metrics.downloads),
                            icon: "arrow.down.circle"))
            if metrics.hasProceeds {
                out.append(Tile(id: "proceeds7d", title: loc(.rmProceeds7d),
                                value: Fmt.number(metrics.proceeds),
                                icon: "eurosign.circle"))
            }
        }

        return out
    }

    /// Weekly analytics metrics that actually carry a value, in catalog order.
    private var weekMetrics: [WeekMetric] {
        guard let snapshot = group.snapshots[.analytics] else { return [] }
        return WeekMetric.extract(from: snapshot.payloadJSON, loc: loc)
    }
}
