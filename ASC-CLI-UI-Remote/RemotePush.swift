import Foundation
import CloudKit
import UserNotifications
import UIKit
import ASCShared

extension Notification.Name {
    /// Posted when a CloudKit remote notification arrives, so the active reader can refresh.
    static let mirrorRemoteChange = Notification.Name("ASCMirrorRemoteChange")
}

// MARK: - Push / subscription wiring (Phase 3b)

/// Registers a CloudKit **database** subscription on the private DB and handles the silent
/// remote notifications it produces, so the phone refreshes when the Mac uploads new
/// snapshots.
///
/// This compiles and runs without the entitlement, but silent pushes only actually arrive
/// once iCloud/Push/Background-modes capabilities are enabled and the app runs on a real
/// device (see `MOBILE_REMOTE.md`). All calls are best-effort and failures are ignored —
/// the UI still works via manual pull-to-refresh.
enum RemotePush {
    /// Stable subscription identifier (idempotent: re-saving the same ID is a no-op upsert).
    static let subscriptionID = "asc-mirror-db-changes"

    /// Requests (provisional) notification authorization and registers for remote
    /// notifications. CloudKit silent pushes don't strictly need user auth, but requesting
    /// it lets us surface alerts too if desired.
    @MainActor
    static func registerForPush(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        application.registerForRemoteNotifications()
    }

    /// Creates the private-database subscription that fires on any change in the mirror zone.
    /// Uses `shouldSendContentAvailable` for a silent (background) push.
    static func ensureSubscription() async {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        let database = CKContainer(identifier: RemoteMirror.containerID).privateCloudDatabase
        _ = try? await database.modifySubscriptions(saving: [subscription], deleting: [])
    }

    /// Routes an incoming remote notification to a refresh. Returns whether it looked like a
    /// CloudKit notification (so the caller can report `.newData` vs `.noData`).
    @MainActor
    static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        let isCloudKit = CKNotification(fromRemoteNotificationDictionary: userInfo) != nil
        NotificationCenter.default.post(name: .mirrorRemoteChange, object: nil)
        return isCloudKit
    }
}

// MARK: - App delegate

/// Minimal app delegate that wires push registration and remote-notification delivery into
/// ``RemotePush``. Attached via `@UIApplicationDelegateAdaptor` in `RemoteApp`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RemotePush.registerForPush(application)
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Device is registered; (re)create the CloudKit subscription.
        Task { await RemotePush.ensureSubscription() }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Non-fatal: push just won't arrive (e.g. simulator / missing entitlement). Manual
        // pull-to-refresh still works.
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let handled = RemotePush.handleRemoteNotification(userInfo)
        completionHandler(handled ? .newData : .noData)
    }

    // Show a banner even if the app is foregrounded (useful while testing).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
