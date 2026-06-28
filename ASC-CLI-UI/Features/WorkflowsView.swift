import SwiftUI

/// Run repeatable repo-local automation workflows defined in `.asc/workflow.json`.
/// Running a workflow executes arbitrary shell commands, so a real run is confirmed first.
struct WorkflowsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    @State private var file = ""
    @State private var name = ""
    @State private var params = ""
    @State private var resume = ""
    @State private var dryRun = true
    @State private var output: String?
    @State private var isRunning = false
    @State private var showRunConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secWorkflows), subtitle: nil) { EmptyView() }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.wfBody)).font(.callout).foregroundStyle(.secondary)

                    Label(loc(.wfSecurityNote), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                    fileCard
                    runCard
                    if let output { OutputPanel(title: loc(.output), text: output, maxHeight: 380) }
                }
                .padding(20)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .alert(loc(.wfRunConfirmTitle), isPresented: $showRunConfirm) {
            Button(loc(.cancel), role: .cancel) {}
            Button(loc(.wfRunNow), role: .destructive) { runWorkflow() }
        } message: {
            Text(loc(.wfRunConfirmMsg))
        }
    }

    private var fileCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                PathPickerRow(label: loc(.wfFile), path: $file, chooseTitle: loc(.rpChooseFolder)) {
                    FilePanel.pickFile(extensions: ["json", "jsonc"])
                }
                Text(".asc/workflow.json").font(.caption2).foregroundStyle(.tertiary)
                HStack(spacing: 10) {
                    Button { run { await ascService.workflowList(file: emptyToNil(file)) } } label: {
                        Label(loc(.wfList), systemImage: "list.bullet")
                    }
                    Button { run { await ascService.workflowValidate(file: emptyToNil(file)) } } label: {
                        Label(loc(.wfValidate), systemImage: "checkmark.seal")
                    }
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.wfFile), systemImage: "doc.text")
        }
    }

    private var runCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc(.wfName)).font(.caption).foregroundStyle(.secondary)
                    TextField("beta", text: $name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc(.wfParams)).font(.caption).foregroundStyle(.secondary)
                    TextField("VERSION:2.1.0 GROUP_ID:abc", text: $params)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(!resume.isEmpty)
                    Text(loc(.wfParamsHint)).font(.caption2).foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc(.wfResume)).font(.caption).foregroundStyle(.secondary)
                    TextField("beta-20260312T120000Z-deadbeef", text: $resume)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text(loc(.wfResumeHint)).font(.caption2).foregroundStyle(.tertiary)
                }
                Toggle(loc(.wfDryRun), isOn: $dryRun).toggleStyle(.checkbox)
                HStack {
                    Spacer()
                    Button {
                        if dryRun { runWorkflow() } else { showRunConfirm = true }
                    } label: {
                        if isRunning {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.wfRunning)) }
                        } else {
                            Label(loc(.wfRun), systemImage: dryRun ? "eye" : "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.wfRun), systemImage: "play.circle")
        }
    }

    private func runWorkflow() {
        let parsedParams = params.split(separator: " ").map(String.init).filter { $0.contains(":") }
        run {
            await ascService.workflowRun(name: name.trimmingCharacters(in: .whitespaces),
                                         file: emptyToNil(file),
                                         params: parsedParams,
                                         dryRun: dryRun,
                                         resume: emptyToNil(resume))
        }
    }

    private func emptyToNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
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
