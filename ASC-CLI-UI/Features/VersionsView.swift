import SwiftUI

struct VersionsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.versionsTitle), subtitle: selectedApp?.name) {
                Button {
                    if let app = selectedApp {
                        Task { await ascService.loadVersions(for: app.id) }
                    }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading || selectedApp == nil)
            }

            Divider()

            if selectedApp == nil {
                ContentUnavailableView(
                    loc(.noAppSelectedTitle),
                    systemImage: "tag.slash",
                    description: Text(loc(.pickAppToolbar))
                )
            } else if ascService.versions.isEmpty && !ascService.isLoading {
                ContentUnavailableView(
                    loc(.noVersions),
                    systemImage: "tag",
                    description: Text(loc(.noVersionsDesc))
                )
            } else {
                Table(ascService.versions) {
                    TableColumn(loc(.colVersion)) { v in
                        Text(v.versionString).fontWeight(.medium)
                    }
                    TableColumn(loc(.colPlatform)) { v in
                        Text(v.platform ?? "—").foregroundStyle(.secondary)
                    }
                    TableColumn(loc(.colState)) { v in
                        VersionStateBadge(state: v.state)
                    }
                    TableColumn(loc(.colRelease)) { v in
                        Text((v.releaseType ?? "—").capitalized.replacingOccurrences(of: "_", with: " "))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn(loc(.colCreated)) { v in
                        Text(v.createdDate.map(ASCDate.relative) ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: selectedApp?.id) {
            if let app = selectedApp { await ascService.ensureVersions(for: app.id) }
        }
    }
}

struct VersionStateBadge: View {
    let state: String

    private var color: Color {
        switch state.uppercased() {
        case "READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "APPROVED": return .green
        case "IN_REVIEW", "WAITING_FOR_REVIEW", "PENDING_DEVELOPER_RELEASE", "PROCESSING_FOR_DISTRIBUTION": return .orange
        case "REJECTED", "DEVELOPER_REJECTED", "INVALID_BINARY", "METADATA_REJECTED": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(state.capitalized.replacingOccurrences(of: "_", with: " "))
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Shared UI helpers

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

enum ASCDate {
    /// Parses an ISO8601 string (with or without fractional seconds) and returns a relative description.
    nonisolated static func relative(_ string: String) -> String {
        guard let date = parse(string) else { return string }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    nonisolated static func short(_ string: String) -> String {
        guard let date = parse(string) else { return string }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: date)
    }

    nonisolated static func parse(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
