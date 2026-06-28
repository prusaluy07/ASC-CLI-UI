import SwiftUI
import AppKit

struct AppsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @Binding var selectedApp: ASCApp?
    @State private var searchText = ""
    @State private var showNewAppInfo = false

    var filteredApps: [ASCApp] {
        if searchText.isEmpty { return ascService.apps }
        return ascService.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar
            HStack {
                Text(loc(.appsTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    showNewAppInfo = true
                } label: {
                    Label(loc(.appsNewApp), systemImage: "plus")
                }
                .popover(isPresented: $showNewAppInfo, arrowEdge: .bottom) {
                    newAppPopover
                }
                Button {
                    Task { await ascService.loadApps() }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if ascService.apps.isEmpty && !ascService.isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppRow(app: app, isSelected: selectedApp?.id == app.id)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedApp = app }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .searchable(text: $searchText, prompt: loc(.searchApps))
            }
        }
        .task {
            if ascService.apps.isEmpty {
                await ascService.loadApps()
            }
        }
    }

    private var newAppPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc(.newAppTitle)).font(.headline)
            Text(loc(.newAppIntro)).font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                stepLine(1, loc(.newAppStep1))
                stepLine(2, loc(.newAppStep2))
                stepLine(3, loc(.newAppStep3))
            }
            HStack {
                Button {
                    NSWorkspace.shared.open(AppInfo.developerIdentifiers)
                } label: {
                    Label(loc(.newAppOpenBundleIds), systemImage: "number.square")
                }
                Button {
                    NSWorkspace.shared.open(AppInfo.appStoreConnectApps)
                } label: {
                    Label(loc(.newAppOpenASC), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private func stepLine(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n).").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(loc(.noAppsLoaded))
                .font(.title3)
            Button(loc(.loadApps)) {
                Task { await ascService.loadApps() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppRow: View {
    let app: ASCApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(app.name.prefix(2)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                Text(app.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let sku = app.sku {
                Text(sku)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
