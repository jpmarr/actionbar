import SwiftUI

struct DispatchView: View {
    @Environment(AppState.self) private var appState
    let workflow: WatchedWorkflow

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { appState.cancelDispatch() }) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
                .foregroundStyle(.secondary)
                .font(.subheadline)

                Spacer()

                Text("Trigger Run")
                    .font(.headline)

                Spacer()
            }
            .padding(.bottom, 4)

            Text("\(workflow.repositoryName) / \(workflow.workflowName)")
                .font(.body)
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
                        .font(.body)
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
                                .font(.body)
                                .foregroundStyle(.secondary)
                            TextField("main", text: $state.dispatchRef)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }

                        if !appState.dispatchInputs.isEmpty {
                            Divider()
                            Text("Inputs")
                                .font(.body)
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
                        .font(.body)
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
    }

    private func inputRow(_ input: WorkflowDispatchInput) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(input.name)
                    .font(.body)
                    .fontWeight(.medium)
                if input.required {
                    Text("required")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            if !input.description.isEmpty {
                Text(input.description)
                    .font(.body)
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
                    .font(.body)
            }
        }
    }
}
