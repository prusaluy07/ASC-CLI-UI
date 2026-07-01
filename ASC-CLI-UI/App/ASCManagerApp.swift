import SwiftUI
import ASCShared

@main
struct ASCManagerApp: App {
    @StateObject private var ascService: ASCService
    @StateObject private var loc = LocalizationManager()
    @StateObject private var cloudSync: CloudKitSync
    @StateObject private var syncEngine: SnapshotEngine
    @StateObject private var metricsEngine: MetricsEngine
    @StateObject private var marketEngine: MarketEngine
    @StateObject private var localAPI: LocalAPIServer

    init() {
        let service = ASCService()
        let sync = CloudKitSync()
        let metrics = MetricsEngine()
        let market = MarketEngine()
        _ascService = StateObject(wrappedValue: service)
        _cloudSync = StateObject(wrappedValue: sync)
        _metricsEngine = StateObject(wrappedValue: metrics)
        _marketEngine = StateObject(wrappedValue: market)
        _syncEngine = StateObject(wrappedValue: SnapshotEngine(
            service: service, uploader: sync, metricsEngine: metrics, marketEngine: market
        ))
        _localAPI = StateObject(wrappedValue: LocalAPIServer())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ascService)
                .environmentObject(loc)
                .environmentObject(cloudSync)
                .environmentObject(syncEngine)
                .environmentObject(metricsEngine)
                .environmentObject(marketEngine)
                .environmentObject(localAPI)
                .frame(minWidth: 960, minHeight: 600)
                .task {
                    localAPI.metricsEngine = metricsEngine
                    localAPI.ascService = ascService
                    await ascService.refreshAuthStatus()
                }
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
                .environmentObject(marketEngine)
        }
    }
}
