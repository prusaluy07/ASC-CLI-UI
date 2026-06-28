import SwiftUI
import ASCShared

// MARK: - Subscriptions

struct SubscriptionsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var groupId = ""

    var body: some View {
        CommandScreen(title: loc(.secSubscriptions), subtitle: selectedApp?.name, intro: loc(.subBody),
                      requireApp: true, hasApp: selectedApp != nil) { _, _ in
            VStack(alignment: .leading, spacing: 14) {
                CommandSection(title: loc(.subGroups), systemImage: "rectangle.stack",
                               autoRun: { await ascService.subscriptionGroups(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.subscriptionGroups(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }

                CommandSection(title: loc(.subSubs), systemImage: "list.bullet") { run, isRunning in
                    HStack(spacing: 10) {
                        TextField(loc(.subGroupId), text: $groupId)
                            .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 280)
                        Button { run { await ascService.subscriptionsList(groupId: groupId) } } label: {
                            Label(loc(.actList), systemImage: "list.bullet")
                        }.disabled(isRunning || groupId.isEmpty)
                        Spacer()
                    }
                }

                CommandSection(title: loc(.subPricing), systemImage: "dollarsign.circle",
                               autoRun: { await ascService.subscriptionsPricing(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.subscriptionsPricing(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }
            }
        }
    }
}

// MARK: - In-App Purchases

struct IAPView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var iapId = ""

    var body: some View {
        CommandScreen(title: loc(.secIAP), subtitle: selectedApp?.name, intro: loc(.iapBody),
                      requireApp: true, hasApp: selectedApp != nil) { _, _ in
            VStack(alignment: .leading, spacing: 14) {
                CommandSection(title: loc(.iapProducts), systemImage: "cart",
                               autoRun: { await ascService.iapList(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    HStack(spacing: 10) {
                        Button { run { await ascService.iapList(appId: selectedApp?.id ?? "") } } label: {
                            Label(loc(.refresh), systemImage: "arrow.clockwise")
                        }.disabled(isRunning)
                        Divider().frame(height: 18)
                        TextField(loc(.iapId), text: $iapId)
                            .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                        Button { run { await ascService.iapView(id: iapId) } } label: {
                            Label(loc(.actView), systemImage: "doc.text.magnifyingglass")
                        }.disabled(isRunning || iapId.isEmpty)
                        Spacer()
                    }
                }

                CommandSection(title: loc(.iapPricing), systemImage: "dollarsign.circle",
                               autoRun: { await ascService.iapPricing(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.iapPricing(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }
            }
        }
    }
}

// MARK: - In-App Events

struct AppEventsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var eventId = ""

    var body: some View {
        CommandScreen(title: loc(.secAppEvents), subtitle: selectedApp?.name, intro: loc(.aeBody),
                      requireApp: true, hasApp: selectedApp != nil) { _, _ in
            CommandSection(title: loc(.secAppEvents), systemImage: "calendar",
                           autoRun: { await ascService.appEventsList(appId: selectedApp?.id ?? "") },
                           autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                HStack(spacing: 10) {
                    Button { run { await ascService.appEventsList(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                    Divider().frame(height: 18)
                    TextField(loc(.aeEventId), text: $eventId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                    Button { run { await ascService.appEventView(eventId: eventId) } } label: {
                        Label(loc(.actView), systemImage: "doc.text.magnifyingglass")
                    }.disabled(isRunning || eventId.isEmpty)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Shared small helper

@ViewBuilder
func actionBox<Controls: View>(_ isRunning: Bool, @ViewBuilder _ controls: () -> Controls) -> some View {
    GroupBox {
        HStack(spacing: 10) {
            controls()
            if isRunning { ProgressView().controlSize(.small) }
            Spacer()
        }
        .padding(6)
    }
}
