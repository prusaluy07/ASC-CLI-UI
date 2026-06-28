import SwiftUI
import ASCShared

/// Phase 3b companion iOS app: a read-only mirror consumer.
///
/// It reads the macOS app's App Store Connect snapshots from the private CloudKit mirror
/// (`CloudKitMirrorReader`), caches them for offline use (`SnapshotCache`), renders them
/// through the shared `OutputView`, and refreshes on a CloudKit push (`RemotePush`). It
/// performs no App Store Connect access and runs no `asc` commands.
@main
struct RemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var loc = LocalizationManager()
    @StateObject private var reader = CloudKitMirrorReader()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(loc)
                .environmentObject(reader)
        }
    }
}
