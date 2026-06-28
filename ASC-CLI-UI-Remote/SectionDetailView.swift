import SwiftUI
import ASCShared

/// Renders a single mirror section using the shared `OutputView`.
///
/// Phase 3a uses hardcoded sample JSON wrapped in a ``Snapshot`` to prove that the
/// cross-platform renderer works on iOS. Phase 3b will replace `sampleSnapshot` with a
/// real `Snapshot` read from the private CloudKit mirror database.
struct SectionDetailView: View {
    @EnvironmentObject private var loc: LocalizationManager
    let section: MirrorSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                placeholderNotice
                OutputView(text: snapshot.payloadJSON)
            }
            .padding()
        }
        .navigationTitle(loc(section.locKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholderNotice: some View {
        Label("Placeholder data — Phase 3b will load this section from the iCloud mirror.",
              systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sample snapshot for the selected section. Mirrors the `Snapshot.payloadJSON`
    /// shape the producer uploads, so the renderer is exercised exactly as it will be
    /// in Phase 3b — only the data source differs.
    private var snapshot: Snapshot {
        Snapshot(appId: "sample",
                 section: section.rawValue,
                 payloadJSON: Self.samplePayload(for: section))
    }

    private static func samplePayload(for section: MirrorSection) -> String {
        switch section {
        case .versions:
            return """
            { "data": [
              { "id": "1", "type": "appStoreVersions",
                "attributes": { "versionString": "1.4.0", "platform": "IOS", "appStoreState": "READY_FOR_SALE" } },
              { "id": "2", "type": "appStoreVersions",
                "attributes": { "versionString": "1.5.0", "platform": "IOS", "appStoreState": "PREPARE_FOR_SUBMISSION" } }
            ] }
            """
        case .builds:
            return """
            { "data": [
              { "id": "b1", "type": "builds",
                "attributes": { "version": "482", "processingState": "VALID", "uploadedDate": "2026-06-20" } },
              { "id": "b2", "type": "builds",
                "attributes": { "version": "483", "processingState": "PROCESSING", "uploadedDate": "2026-06-27" } }
            ] }
            """
        case .subscriptions:
            return """
            { "subscriptions": [
              { "name": "Pro Monthly", "productId": "pro.monthly", "state": "APPROVED",
                "currentPrice": { "amount": "4.99", "currency": "USD" } },
              { "name": "Pro Yearly", "productId": "pro.yearly", "state": "APPROVED",
                "currentPrice": { "amount": "49.99", "currency": "USD" } }
            ] }
            """
        case .pricing:
            return """
            { "data": [
              { "name": "Base Tier", "territory": "USA", "state": "ACTIVE",
                "price": { "amount": "2.99", "currency": "USD" } }
            ] }
            """
        case .betaGroups:
            return """
            { "data": [
              { "name": "Internal QA", "state": "ENABLED", "type": "internal" },
              { "name": "Public Beta", "state": "ENABLED", "type": "external" }
            ] }
            """
        case .reviews:
            return """
            { "averageRating": "4.6", "ratingCount": "1287" }
            """
        case .status:
            return """
            { "summary": { "health": "READY", "nextAction": "Submit build 483 for review" },
              "appstore": { "state": "READY_FOR_SALE" },
              "review": { "state": "COMPLETED" } }
            """
        }
    }
}

#Preview {
    NavigationStack {
        SectionDetailView(section: .versions)
            .environmentObject(LocalizationManager())
    }
}
