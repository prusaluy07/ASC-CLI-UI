import SwiftUI
import ASCShared

/// Renders a single mirrored section's real ``Snapshot`` (read from CloudKit / cache) using
/// the shared `OutputView`, with a "last updated" header.
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
                OutputView(text: snapshot.payloadJSON)
            }
            .padding()
        }
        .navigationTitle(loc(section.locKey))
        .navigationBarTitleDisplayMode(.inline)
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
        default:
            payload = #"{ "data": [ { "id": "a", "name": "Example", "state": "ACTIVE" } ] }"#
        }
        return Snapshot(appId: "123456789",
                        section: section.rawValue,
                        payloadJSON: payload,
                        summary: RemoteMirror.summarize(section: section, payloadJSON: payload))
    }
}

#Preview {
    NavigationStack {
        SectionDetailView(snapshot: .previewSample(.versions), section: .versions)
            .environmentObject(LocalizationManager())
    }
}
#endif
