import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    @State private var tab = 0
    @State private var searchQuery = ""
    @State private var schemaQuery = ""
    @State private var output: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.discoverTitle), subtitle: nil) { EmptyView() }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.discoverBody)).font(.callout).foregroundStyle(.secondary)

                    Picker("", selection: $tab) {
                        Text(loc(.discSearch)).tag(0)
                        Text(loc(.discSchema)).tag(1)
                        Text(loc(.discCapabilities)).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch tab {
                    case 0: searchPane
                    case 1: schemaPane
                    default: capabilitiesPane
                    }

                    if let output { OutputPanel(title: loc(.rpResult), text: output, maxHeight: 420) }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var searchPane: some View {
        HStack(spacing: 10) {
            TextField(loc(.discSearchPlaceholder), text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit { runSearch() }
            Button { runSearch() } label: { Label(loc(.discSearch), systemImage: "magnifyingglass") }
                .disabled(isRunning || searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            if isRunning { ProgressView().controlSize(.small) }
        }
    }

    private var schemaPane: some View {
        HStack(spacing: 10) {
            TextField(loc(.discSchemaPlaceholder), text: $schemaQuery)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit { run { await ascService.schemaLookup(schemaQuery) } }
            Button { run { await ascService.schemaLookup(schemaQuery) } } label: {
                Label(loc(.discLookup), systemImage: "curlybraces")
            }
            .disabled(isRunning)
            if isRunning { ProgressView().controlSize(.small) }
        }
    }

    private var capabilitiesPane: some View {
        HStack(spacing: 10) {
            Button { run { await ascService.capabilities() } } label: {
                Label(loc(.discLoadCapabilities), systemImage: "checklist.checked")
            }
            .disabled(isRunning)
            if isRunning { ProgressView().controlSize(.small) }
            Spacer()
        }
    }

    private func runSearch() {
        run { await ascService.searchCommands(searchQuery) }
    }

    private func run(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        output = nil
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "—" : result.output) : result.errorMessage
            isRunning = false
        }
    }
}
