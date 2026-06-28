import SwiftUI

@main
struct ASCManagerApp: App {
    @StateObject private var ascService = ASCService()
    @StateObject private var loc = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ascService)
                .environmentObject(loc)
                .frame(minWidth: 960, minHeight: 600)
                .task { await ascService.refreshAuthStatus() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(ascService)
                .environmentObject(loc)
        }
    }
}
