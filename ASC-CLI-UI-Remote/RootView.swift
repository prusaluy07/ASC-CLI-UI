import SwiftUI
import ASCShared

/// Lists the App Store Connect sections that the macOS app can mirror to iCloud and,
/// on selection, pushes a detail screen that renders sample data through the shared
/// `OutputView`. Labels reuse the shared `LocalizationManager` / `LocKey` table.
struct RootView: View {
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        NavigationStack {
            List(MirrorSection.allCases) { section in
                NavigationLink(value: section) {
                    Label(loc(section.locKey), systemImage: icon(for: section))
                }
            }
            .navigationTitle(loc(.appName))
            .navigationDestination(for: MirrorSection.self) { section in
                SectionDetailView(section: section)
            }
        }
    }

    private func icon(for section: MirrorSection) -> String {
        switch section {
        case .status:        return "checkmark.seal"
        case .versions:      return "number"
        case .builds:        return "hammer"
        case .betaGroups:    return "person.3"
        case .reviews:       return "star"
        case .pricing:       return "tag"
        case .subscriptions: return "repeat"
        }
    }
}

#Preview {
    RootView()
        .environmentObject(LocalizationManager())
}
