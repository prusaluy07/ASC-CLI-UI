import SwiftUI
import ASCShared

/// Renders a single mirrored section's real ``Snapshot`` (read from CloudKit / cache),
/// with a "last updated" header. Sections with a known payload shape get a native,
/// typed rendering (lists with state badges, trend chart, stat tiles); everything
/// else — including any payload that fails to parse — falls back to the shared
/// schema-agnostic `OutputView`.
struct SectionDetailView: View {
    @EnvironmentObject private var loc: LocalizationManager
    let snapshot: Snapshot
    let section: MirrorSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.rmUpdatedFmt, formatted(snapshot.capturedAt)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                content
            }
            .padding()
        }
        .navigationTitle(loc(section.locKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .versions:
            if let versions = decodeList(ASCVersion.self), !versions.isEmpty {
                cardStack(versions) { version in
                    recordCard(title: version.versionString,
                               badge: version.state,
                               detail: [version.platform, version.createdDate.map(day)]
                                   .compactMap { $0 }.joined(separator: " · "))
                }
            } else {
                rawFallback
            }
        case .builds:
            if let builds = decodeList(ASCBuild.self), !builds.isEmpty {
                cardStack(builds) { build in
                    recordCard(title: build.buildNumber,
                               badge: build.processingState,
                               detail: [build.minOsVersion.map { "iOS \($0)+" },
                                        build.uploadedDate.map(day)]
                                   .compactMap { $0 }.joined(separator: " · "))
                }
            } else {
                rawFallback
            }
        case .betaGroups:
            if let groups = decodeList(ASCBetaGroup.self), !groups.isEmpty {
                cardStack(groups) { group in
                    recordCard(title: group.name,
                               badge: group.isInternal ? loc(.rmInternalGroup) : nil,
                               detail: group.createdDate.map(day) ?? "")
                }
            } else {
                rawFallback
            }
        case .storedMetrics:
            if let payload = StoredMetricsPayload.decode(snapshot.payloadJSON) {
                storedMetricsDetail(payload)
            } else {
                rawFallback
            }
        case .marketRank:
            if let rank = MarketRankPayload.decode(snapshot.payloadJSON) {
                marketRankDetail(rank)
            } else {
                rawFallback
            }
        case .reviews:
            if let ratings = ReviewRatingsParser.parse(snapshot.payloadJSON),
               ratings.averageRating != nil || ratings.ratingCount != nil {
                ratingsDetail(ratings)
            } else {
                rawFallback
            }
        case .analytics:
            if !weekMetrics.isEmpty {
                analyticsDetail
            } else {
                rawFallback
            }
        case .status, .pricing, .subscriptions, .inAppPurchases:
            rawFallback
        }
    }

    private var rawFallback: some View {
        OutputView(text: snapshot.payloadJSON)
    }

    // MARK: Typed list rendering

    private func cardStack<T: Identifiable, Row: View>(_ items: [T],
                                                       @ViewBuilder row: @escaping (T) -> Row) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(items) { row($0) }
        }
    }

    private func recordCard(title: String, badge: String?, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let badge, !badge.isEmpty {
                StateBadge(text: badge)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Section-specific detail

    private func storedMetricsDetail(_ payload: StoredMetricsPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatTile(title: loc(.rmDownloads7d), value: Fmt.integer(payload.downloads),
                         systemImage: "arrow.down.circle")
                if payload.hasProceeds {
                    StatTile(title: loc(.rmProceeds7d), value: Fmt.number(payload.proceeds),
                             systemImage: "eurosign.circle")
                }
                StatTile(title: loc(.anReturns), value: Fmt.integer(payload.returns),
                         systemImage: "arrow.uturn.left.circle")
            }
            TrendChartCard(payload: payload)
            Text(loc(.msFromReports))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func marketRankDetail(_ rank: MarketRankPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatTile(title: loc(.rmRank),
                     value: rankValue(rank),
                     caption: "\(rank.chart) · \(rank.country.uppercased())",
                     systemImage: "chart.bar")
            Text(rank.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rankValue(_ rank: MarketRankPayload) -> String {
        guard let delta = rank.delta, delta != 0 else { return "#\(rank.rank)" }
        // Negative delta = climbed the chart (smaller rank number).
        return "#\(rank.rank) \(delta < 0 ? "↑\(abs(delta))" : "↓\(delta)")"
    }

    private func ratingsDetail(_ ratings: ReviewRatingsSummary) -> some View {
        StatTile(title: loc(.rmRating),
                 value: ratings.averageRating.map { "★ \(Fmt.number($0))" } ?? "—",
                 caption: ratings.ratingCount.map { loc(.rmRatingsCountFmt, $0) },
                 systemImage: "star")
    }

    private var analyticsDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc(.rmWeekCompare))
                .font(.subheadline.weight(.semibold))
            ForEach(weekMetrics) { entry in
                MetricCompareRow(label: entry.label, metric: entry.metric)
                Divider()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var weekMetrics: [WeekMetric] {
        WeekMetric.extract(from: snapshot.payloadJSON, loc: loc)
    }

    // MARK: Helpers

    private func decodeList<T: Decodable>(_ type: T.Type) -> [T]? {
        try? ASCJSONList.decode(snapshot.payloadJSON, as: type).items
    }

    /// Shortens an ISO timestamp ("2026-06-30T09:41:00Z" or "2026-06-30") to its day part.
    private func day(_ iso: String) -> String {
        String(iso.prefix(10))
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

#if DEBUG
extension Snapshot {
    /// Sample snapshot for SwiftUI previews only (not used at runtime).
    static func previewSample(_ section: MirrorSection) -> Snapshot {
        let payload: String
        switch section {
        case .versions:
            payload = #"{ "data": [ { "id": "1", "attributes": { "versionString": "1.4.0", "appStoreState": "READY_FOR_SALE" } } ] }"#
        case .status:
            payload = #"{ "summary": { "health": "READY", "nextAction": "Submit build 483" }, "appstore": { "state": "READY_FOR_SALE" } }"#
        case .storedMetrics:
            payload = #"{ "appId": "1", "days": 7, "downloads": 42, "proceeds": 12.5, "returns": 1, "trend": [ { "date": "2026-06-20", "downloads": 3, "proceeds": 1.0, "iapUnits": 0, "updates": 0, "returns": 0, "subscriptionUnits": 0 }, { "date": "2026-06-21", "downloads": 7, "proceeds": 2.5, "iapUnits": 0, "updates": 0, "returns": 0, "subscriptionUnits": 0 } ] }"#
        default:
            payload = #"{ "data": [ { "id": "a", "name": "Example", "state": "ACTIVE" } ] }"#
        }
        return Snapshot(appId: "123456789",
                        section: section.rawValue,
                        payloadJSON: payload,
                        summary: RemoteMirror.summarize(section: section, payloadJSON: payload))
    }
}

#Preview("Versions") {
    NavigationStack {
        SectionDetailView(snapshot: .previewSample(.versions), section: .versions)
            .environmentObject(LocalizationManager())
    }
}

#Preview("Stored metrics") {
    NavigationStack {
        SectionDetailView(snapshot: .previewSample(.storedMetrics), section: .storedMetrics)
            .environmentObject(LocalizationManager())
    }
}
#endif
