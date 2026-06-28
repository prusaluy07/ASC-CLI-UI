import SwiftUI
import ASCShared

struct XcodeCloudView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var workflow = ""
    @State private var branch = "main"
    @State private var runId = ""
    @State private var wait = false
    @State private var output: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.xcTitle), subtitle: selectedApp?.name) {
                Button {
                    if let app = selectedApp { run { await ascService.xcWorkflows(appId: app.id) } }
                } label: {
                    Label(loc(.xcWorkflows), systemImage: "arrow.clockwise")
                }
                .disabled(isRunning || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "cloud",
                                       description: Text(loc(.selectAppFromApps)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        triggerCard
                        statusCard
                        if let output { OutputPanel(title: loc(.output), text: output, maxHeight: 360) }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var triggerCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.xcBody)).font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(.xcWorkflowName)).font(.caption).foregroundStyle(.secondary)
                        TextField("CI", text: $workflow).textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(.xcBranch)).font(.caption).foregroundStyle(.secondary)
                        TextField("main", text: $branch).textFieldStyle(.roundedBorder)
                    }
                }
                Toggle(loc(.xcWait), isOn: $wait).toggleStyle(.checkbox)
                HStack {
                    Spacer()
                    Button {
                        guard let app = selectedApp else { return }
                        run { await ascService.xcRun(appId: app.id, workflow: workflow, branch: branch, wait: wait) }
                    } label: {
                        Label(loc(.xcRun), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || workflow.isEmpty || branch.isEmpty)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.xcTrigger), systemImage: "play.circle")
        }
    }

    private var statusCard: some View {
        GroupBox {
            HStack(spacing: 10) {
                TextField(loc(.xcRunId), text: $runId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Toggle(loc(.xcWait), isOn: $wait).toggleStyle(.checkbox)
                Button {
                    run { await ascService.xcStatus(runId: runId, wait: wait) }
                } label: {
                    Label(loc(.xcCheckStatus), systemImage: "info.circle")
                }
                .disabled(isRunning || runId.isEmpty)
                if isRunning { ProgressView().controlSize(.small) }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.xcBuildRunStatus), systemImage: "wave.3.right")
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
