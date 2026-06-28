import SwiftUI

/// Marketplace and alternative distribution resources (domains, keys, packages, webhooks).
/// App-specific actions use the app selected in the toolbar.
struct DistributionView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var tab = 0
    @State private var packageId = ""
    @State private var output: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secDistribution), subtitle: selectedApp?.name) { EmptyView() }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.distBody)).font(.callout).foregroundStyle(.secondary)

                    Picker("", selection: $tab) {
                        Text(loc(.distAltDist)).tag(0)
                        Text(loc(.distMarketplace)).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if tab == 0 { altDistPane } else { marketplacePane }

                    if let output { OutputPanel(title: loc(.output), text: output, maxHeight: 380) }
                }
                .padding(20)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var altDistPane: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.distAppNote)).font(.caption).foregroundStyle(.tertiary)
                HStack(spacing: 10) {
                    Button { run { await ascService.altDistDomainsList() } } label: {
                        Label(loc(.distDomains), systemImage: "globe")
                    }
                    Button { run { await ascService.altDistKeysList() } } label: {
                        Label(loc(.distKeys), systemImage: "key")
                    }
                    Button {
                        guard let app = selectedApp else { return }
                        run { await ascService.altDistKeyForApp(appId: app.id) }
                    } label: {
                        Label(loc(.distAppKey), systemImage: "key.viewfinder")
                    }
                    .disabled(selectedApp == nil)
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
                Divider()
                HStack(spacing: 10) {
                    TextField(loc(.distPackageId), text: $packageId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 260)
                    Button { run { await ascService.altDistPackageView(packageId: packageId) } } label: {
                        Label(loc(.distViewPackage), systemImage: "shippingbox")
                    }
                    .disabled(isRunning || packageId.isEmpty)
                    Spacer()
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.distAltDist), systemImage: "point.3.connected.trianglepath.dotted")
        }
    }

    private var marketplacePane: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.distAppNote)).font(.caption).foregroundStyle(.tertiary)
                HStack(spacing: 10) {
                    Button { run { await ascService.marketplaceWebhooksList() } } label: {
                        Label(loc(.distWebhooks), systemImage: "bell.badge")
                    }
                    Button {
                        guard let app = selectedApp else { return }
                        run { await ascService.marketplaceSearchDetails(appId: app.id) }
                    } label: {
                        Label(loc(.distSearchDetails), systemImage: "magnifyingglass")
                    }
                    .disabled(selectedApp == nil)
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.distMarketplace), systemImage: "storefront")
        }
    }

    private func run(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        output = nil
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
        }
    }
}
