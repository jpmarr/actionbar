import SwiftUI

struct DispatchView: View {
    @Environment(AppState.self) private var appState
    let workflow: WatchedWorkflow

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { appState.cancelDispatch() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text("Trigger Run")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)

            Text("\(workflow.repositoryName) / \(workflow.workflowName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            if appState.isLoadingDispatch && appState.dispatchInputs.isEmpty {
                Spacer()
                ProgressView("Loading workflow inputs...")
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else if appState.dispatchSuccess {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Workflow dispatch triggered!")
                        .font(.subheadline)
                    Text("The run should appear shortly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()

                Button("Done") {
                    appState.cancelDispatch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Branch/Ref")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("main", text: $state.dispatchRef)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }

                        if !appState.dispatchInputs.isEmpty {
                            Divider()
                            Text("Inputs")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            ForEach(appState.dispatchInputs) { input in
                                inputRow(input)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if let error = appState.dispatchError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Trigger") {
                        Task { await appState.executeDispatch() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(appState.isLoadingDispatch || appState.dispatchRef.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding()
        .frame(minWidth: 480, maxWidth: 480, minHeight: 250, maxHeight: 450)
    }

    private func inputRow(_ input: WorkflowDispatchInput) -> some View {
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
                get: { appState.dispatchInputValues[input.name] ?? "" },
                set: { appState.dispatchInputValues[input.name] = $0 }
            )

            switch input.type {
            case .boolean:
                let boolBinding = Binding<Bool>(
                    get: { (appState.dispatchInputValues[input.name] ?? input.defaultValue).lowercased() == "true" },
                    set: { appState.dispatchInputValues[input.name] = $0 ? "true" : "false" }
                )
                Toggle(input.name, isOn: boolBinding)
                    .labelsHidden()
                    .toggleStyle(.checkbox)

            case .choice:
                Picker("", selection: binding) {
                    ForEach(input.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

            case .string, .number, .environment:
                TextField(input.defaultValue.isEmpty ? input.name : input.defaultValue, text: binding)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
    }
}
