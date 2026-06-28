import SwiftUI
import ASCShared

/// Phase 3a companion iOS app.
///
/// This target only proves that the shared `ASCShared` package builds and renders on
/// iOS. It contains no CloudKit reading, push notifications, networking or App Store
/// Connect access — those land in Phase 3b. The UI is a thin shell around the shared
/// `OutputView`, fed with placeholder data.
@main
struct RemoteApp: App {
    @StateObject private var loc = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(loc)
        }
    }
}
