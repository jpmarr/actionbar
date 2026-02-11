import SwiftUI

struct WorkflowPickerView: View {
    @Environment(AppState.self) private var appState
    let repository: Repository

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    appState.selectedRepository = nil
                    appState.availableWorkflows = []
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Repos")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
                .foregroundStyle(.secondary)
                .font(.subheadline)

                Spacer()

                Text(repository.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Divider()
                .padding(.vertical, 8)

            if appState.isLoadingWorkflows {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else if appState.availableWorkflows.isEmpty {
                Spacer()
                Text("No active workflows found")
                    .foregroundStyle(.secondary)
                    .font(.body)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.availableWorkflows) { workflow in
                            workflowRow(workflow)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func workflowRow(_ workflow: Workflow) -> some View {
        Button {
            appState.toggleWatch(workflow: workflow, in: repository)
        } label: {
            HStack {
                Image(systemName: appState.isWatching(workflowId: workflow.id) ? "eye.fill" : "eye.slash")
                    .foregroundStyle(appState.isWatching(workflowId: workflow.id) ? .blue : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(workflow.name)
                        .font(.system(.body, weight: .medium))
                    Text(workflow.path)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appState.isWatching(workflowId: workflow.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .font(.body)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
