import SwiftUI
import ASCShared

/// Lists the mirrored sections for a single app, each with a "last updated" stamp and a
/// short summary line, and pushes a ``SectionDetailView`` rendering the real snapshot.
struct AppSectionsView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var reader: CloudKitMirrorReader
    let appId: String

    private var group: MirrorAppGroup? { reader.group(for: appId) }

    var body: some View {
        List {
            if let group {
                ForEach(group.orderedSections) { section in
                    if let snapshot = group.snapshots[section] {
                        NavigationLink(value: SectionRoute(appId: appId, section: section)) {
                            sectionRow(section: section, snapshot: snapshot)
                        }
                    }
                }
            } else {
                ContentUnavailableView(loc(.rmEmptyTitle), systemImage: "icloud.slash")
            }
        }
        .navigationTitle(group?.appName ?? loc(.rmAppFmt, appId))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reader.refresh() }
    }

    private func sectionRow(section: MirrorSection, snapshot: Snapshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: section))
                .frame(width: 26)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(loc(section.locKey)).font(.body)
                if let headline = summaryLine(snapshot) {
                    Text(headline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(loc(.rmUpdatedFmt, RootView.relative(snapshot.capturedAt)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    /// A compact one-line headline from the snapshot's pre-computed summary, if any.
    private func summaryLine(_ snapshot: Snapshot) -> String? {
        // `appName` is metadata for the title, not a section headline — drop it here.
        let summary = (snapshot.summary ?? [:]).filter { $0.key != "appName" }
        guard !summary.isEmpty else { return nil }
        let priority = ["health", "latestVersion", "latestBuild", "averageRating", "count"]
        if let key = priority.first(where: { summary[$0] != nil }), let value = summary[key] {
            return value
        }
        return summary.sorted { $0.key < $1.key }.first.map { "\($0.value)" }
    }

    private func icon(for section: MirrorSection) -> String {
        switch section {
        case .status:         return "checkmark.seal"
        case .versions:       return "number"
        case .builds:         return "hammer"
        case .betaGroups:     return "person.3"
        case .reviews:        return "star"
        case .pricing:        return "tag"
        case .subscriptions:  return "repeat"
        case .inAppPurchases: return "cart"
        case .analytics:      return "chart.xyaxis.line"
        }
    }
}
