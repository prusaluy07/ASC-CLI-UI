import SwiftUI
import ASCShared

@main
struct ASCManagerApp: App {
    @StateObject private var ascService: ASCService
    @StateObject private var loc = LocalizationManager()
    @StateObject private var cloudSync: CloudKitSync
    @StateObject private var syncEngine: SnapshotEngine
    @StateObject private var metricsEngine: MetricsEngine

    init() {
        let service = ASCService()
        let sync = CloudKitSync()
        _ascService = StateObject(wrappedValue: service)
        _cloudSync = StateObject(wrappedValue: sync)
        _syncEngine = StateObject(wrappedValue: SnapshotEngine(service: service, uploader: sync))
        _metricsEngine = StateObject(wrappedValue: MetricsEngine())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ascService)
                .environmentObject(loc)
                .environmentObject(cloudSync)
                .environmentObject(syncEngine)
                .environmentObject(metricsEngine)
                .frame(minWidth: 960, minHeight: 600)
                .task { await ascService.refreshAuthStatus() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(presentation: .preferences)
                .environmentObject(ascService)
                .environmentObject(loc)
                .environmentObject(cloudSync)
                .environmentObject(syncEngine)
                .environmentObject(metricsEngine)
        }
    }
}
