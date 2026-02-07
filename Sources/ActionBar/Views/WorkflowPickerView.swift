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
                    Image(systemName: "chevron.left")
                    Text("Repos")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

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
                    .font(.caption)
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
                        .font(.system(.caption, weight: .medium))
                    Text(workflow.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appState.isWatching(workflowId: workflow.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
