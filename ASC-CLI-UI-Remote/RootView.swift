import SwiftUI
import ASCShared

/// Navigation value identifying a single mirrored section within an app.
struct SectionRoute: Hashable {
    let appId: String
    let section: MirrorSection
}

/// Top level: lists the apps mirrored into the private CloudKit database. Loads the offline
/// cache immediately, then refreshes from CloudKit. Supports pull-to-refresh, a manual
/// refresh button, push-driven refresh, and a localized empty/error state.
struct RootView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var reader: CloudKitMirrorReader

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(loc(.rmAppsTitle))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await reader.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(reader.isRefreshing)
                    }
                }
                .navigationDestination(for: String.self) { appId in
                    AppSectionsView(appId: appId)
                }
                .navigationDestination(for: SectionRoute.self) { route in
                    if let snapshot = reader.snapshot(appId: route.appId, section: route.section) {
                        SectionDetailView(snapshot: snapshot, section: route.section)
                    } else {
                        ContentUnavailableView(loc(.rmEmptyTitle),
                                               systemImage: "icloud.slash")
                    }
                }
        }
        .task {
            reader.loadCache()
            await reader.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mirrorRemoteChange)) { _ in
            Task { await reader.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if reader.hasData {
            List {
                if let error = reader.errorMessage {
                    Section { errorRow(error) }
                }
                Section {
                    ForEach(reader.groups) { group in
                        NavigationLink(value: group.appId) {
                            appRow(group)
                        }
                    }
                }
            }
            .refreshable { await reader.refresh() }
        } else if reader.isRefreshing && !reader.didLoadCache {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyState
        }
    }

    private func appRow(_ group: MirrorAppGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc(.rmAppFmt, group.appId))
                .font(.headline)
            HStack(spacing: 8) {
                Text(loc(.outCountFmt, group.snapshots.count))
                if let updated = group.lastUpdated {
                    Text("·")
                    Text(loc(.rmUpdatedFmt, Self.relative(updated)))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func errorRow(_ message: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc(.rmLoadError)).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange)
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack {
                if let error = reader.errorMessage {
                    ContentUnavailableView {
                        Label(loc(.rmLoadError), systemImage: "exclamationmark.icloud")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(loc(.refresh)) { Task { await reader.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView {
                        Label(loc(.rmEmptyTitle), systemImage: "icloud")
                    } description: {
                        Text(loc(.rmEmptyMessage))
                    } actions: {
                        Button(loc(.refresh)) { Task { await reader.refresh() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
        .refreshable { await reader.refresh() }
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    RootView()
        .environmentObject(LocalizationManager())
        .environmentObject(CloudKitMirrorReader())
}
