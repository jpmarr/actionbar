import SwiftUI

struct DispatchConfigView: View {
    @Environment(AppState.self) private var appState
    let workflow: WatchedWorkflow

    @State private var defaultRef: String = "main"
    @State private var localRepoPath: String = ""
    @State private var inputDefaults: [String: InputDefault] = [:]
    @State private var inputs: [WorkflowDispatchInput] = []
    @State private var isLoadingInputs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { appState.cancelDispatchConfig() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text("Configure Dispatch")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)

            Text("\(workflow.repositoryName) / \(workflow.workflowName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Branch/Ref")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("main", text: $defaultRef)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Repo Path")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        PathTextField(path: $localRepoPath)
                    }

                    if isLoadingInputs {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if !inputs.isEmpty {
                        Divider()
                        Text("Input Defaults")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(inputs) { input in
                            inputDefaultRow(input)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(minWidth: 480, maxWidth: 480, minHeight: 250, maxHeight: 450)
        .task {
            loadExisting()
            await loadInputs()
        }
    }

    private func inputDefaultRow(_ input: WorkflowDispatchInput) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(input.name)
                    .font(.caption)
                    .fontWeight(.medium)
                if input.required {
                    Text("required")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                }
            }
            if !input.description.isEmpty {
                Text(input.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            let binding = Binding<String>(
                get: { inputDefaults[input.name]?.value ?? input.defaultValue },
                set: { newValue in
                    var d = inputDefaults[input.name] ?? InputDefault()
                    d.value = newValue
                    inputDefaults[input.name] = d
                }
            )

            let useBranchBinding = Binding<Bool>(
                get: { inputDefaults[input.name]?.useCurrentBranch ?? false },
                set: { newValue in
                    var d = inputDefaults[input.name] ?? InputDefault()
                    d.useCurrentBranch = newValue
                    inputDefaults[input.name] = d
                }
            )

            if input.type == .choice {
                Picker("", selection: binding) {
                    ForEach(input.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            } else {
                TextField("Default value", text: binding)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            Toggle("Use current branch", isOn: useBranchBinding)
                .font(.caption2)
                .toggleStyle(.checkbox)
        }
    }

    private func loadExisting() {
        if let config = appState.dispatchConfigStorage.loadConfig(for: workflow.id) {
            defaultRef = config.defaultRef
            localRepoPath = config.localRepoPath ?? ""
            inputDefaults = config.inputDefaults
        }
    }

    private func loadInputs() async {
        isLoadingInputs = true
        do {
            let workflowsResponse = try await appState.gitHubClient.fetchWorkflows(
                owner: workflow.repositoryOwner,
                repo: workflow.repositoryName
            )
            if let wf = workflowsResponse.workflows.first(where: { $0.id == workflow.workflowId }) {
                let yamlContent = try await appState.gitHubClient.fetchWorkflowFileContent(
                    owner: workflow.repositoryOwner,
                    repo: workflow.repositoryName,
                    path: wf.path
                )
                inputs = WorkflowInputParser.parseInputs(from: yamlContent)
            }
        } catch {
            // Non-fatal — user can still set ref and local path
        }
        isLoadingInputs = false
    }

    private func save() {
        let config = DispatchConfig(
            workflowKey: workflow.id,
            defaultRef: defaultRef,
            localRepoPath: localRepoPath.isEmpty ? nil : localRepoPath,
            inputDefaults: inputDefaults
        )
        try? appState.dispatchConfigStorage.saveConfig(config)
        appState.cancelDispatchConfig()
    }
}
