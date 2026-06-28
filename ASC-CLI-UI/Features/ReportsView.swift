import SwiftUI
import AppKit

struct ReportsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var frequency = "DAILY"
    @State private var salesDate = ""
    @State private var financeRegion = "US"
    @State private var financeDate = ""
    @State private var decompress = true
    @State private var output: String?
    @State private var lastSavedPath: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.reportsTitle), subtitle: selectedApp?.name) { EmptyView() }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    vendorCard
                    folderCard
                    if ascService.vendorNumber.isEmpty {
                        Label(loc(.rpNeedVendor), systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    analyticsCard
                    salesCard
                    financeCard
                    if let output {
                        outputCard(output)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear(perform: prefillDates)
    }

    private var folderCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(ascService.reportsDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button(loc(.rpChooseFolder)) { chooseFolder() }
                }
                Toggle(loc(.rpDecompress), isOn: $decompress)
                    .toggleStyle(.checkbox)
                    .font(.callout)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.rpFolder), systemImage: "tray.and.arrow.down")
        }
    }

    private var vendorCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("88888888", text: $ascService.vendorNumber)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 220)
                    Button(loc(.rpSaveVendor)) { ascService.saveSettings() }
                    Spacer()
                }
                Text(loc(.rpVendorHint)).font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.rpVendor), systemImage: "number")
        }
    }

    private var analyticsCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                Button {
                    if let app = selectedApp { run { await ascService.createAnalyticsRequest(appId: app.id) } }
                } label: {
                    Label(loc(.rpCreateRequest), systemImage: "plus.rectangle.on.folder")
                }
                .disabled(selectedApp == nil || isRunning)

                Button {
                    if let app = selectedApp { run { await ascService.analyticsRequests(appId: app.id) } }
                } label: {
                    Label(loc(.rpRequests), systemImage: "list.bullet.rectangle")
                }
                .disabled(selectedApp == nil || isRunning)
                Spacer()
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.rpAnalytics), systemImage: "chart.bar")
        }
    }

    private var salesCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                Picker(loc(.rpFrequency), selection: $frequency) {
                    Text(loc(.rpDaily)).tag("DAILY")
                    Text(loc(.rpWeekly)).tag("WEEKLY")
                    Text(loc(.rpMonthly)).tag("MONTHLY")
                }
                .frame(maxWidth: 160)

                TextField(loc(.rpDate), text: $salesDate)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)

                Button {
                    let path = outputPath(name: "sales_summary_\(frequency.lowercased())_\(salesDate)")
                    run(savedPath: path) {
                        await ascService.salesReport(date: salesDate, frequency: frequency,
                                                     outputPath: path, decompress: decompress)
                    }
                } label: {
                    Label(loc(.rpDownload), systemImage: "arrow.down.circle")
                }
                .disabled(ascService.vendorNumber.isEmpty || salesDate.isEmpty || isRunning)
                Spacer()
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.rpSalesReport), systemImage: "cart")
        }
    }

    private var financeCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                TextField(loc(.rpRegion), text: $financeRegion)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                TextField(loc(.rpFinanceReport), text: $financeDate)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                Button {
                    let path = outputPath(name: "finance_FINANCIAL_\(financeRegion)_\(financeDate)")
                    run(savedPath: path) {
                        await ascService.financeReport(date: financeDate, region: financeRegion,
                                                       outputPath: path, decompress: decompress)
                    }
                } label: {
                    Label(loc(.rpDownload), systemImage: "arrow.down.circle")
                }
                .disabled(ascService.vendorNumber.isEmpty || financeDate.isEmpty || isRunning)

                Button {
                    run { await ascService.financeRegions() }
                } label: {
                    Label(loc(.rpFinanceRegions), systemImage: "globe")
                }
                .disabled(isRunning)
                Spacer()
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.rpFinance), systemImage: "banknote")
        }
    }

    private func outputCard(_ text: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let saved = lastSavedPath {
                    HStack {
                        Text(loc(.rpSavedToFmt, saved))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(loc(.rpReveal)) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: saved)])
                        }
                        .controlSize(.small)
                    }
                }
                ScrollView {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }
            .padding(6)
        } label: {
            Label(loc(.rpResult), systemImage: "doc.plaintext")
        }
    }

    /// Builds a full output file path inside the chosen reports folder.
    private func outputPath(name: String) -> String {
        let ext = decompress ? "tsv" : "tsv.gz"
        let dir = ascService.reportsDirectory
        return (dir as NSString).appendingPathComponent("\(name).\(ext)")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: ascService.reportsDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            ascService.reportsDirectory = url.path
            ascService.saveSettings()
        }
    }

    private func run(savedPath: String? = nil, _ operation: @escaping () async -> CommandResult) {
        isRunning = true
        output = nil
        lastSavedPath = nil
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            if result.succeeded, let savedPath, FileManager.default.fileExists(atPath: savedPath) {
                lastSavedPath = savedPath
            }
            isRunning = false
        }
    }

    private func prefillDates() {
        if salesDate.isEmpty {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            salesDate = f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
        }
        if financeDate.isEmpty {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM"
            financeDate = f.string(from: Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now)
        }
    }
}
