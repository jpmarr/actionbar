import SwiftUI

struct WorkflowRunsListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(appState.watchedWorkflows) { workflow in
                    workflowSection(workflow)
                }
            }
            .padding(.horizontal)
        }
    }

    private func workflowSection(_ workflow: WatchedWorkflow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workflow.repositoryName)
                    .font(.system(.caption, weight: .semibold))
                Text(workflow.workflowName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let branch = appState.detectedBranches[workflow.id] {
                    Text("\u{00B7}")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    Task { await appState.prepareDispatch(for: workflow) }
                } label: {
                    Image(systemName: "play.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Trigger run")

                Button {
                    appState.showDispatchConfig(for: workflow)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure dispatch")

                Button {
                    appState.removeWatchedWorkflow(workflow)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Stop watching")
            }

            let runs = appState.workflowRuns[workflow.workflowId] ?? []
            if let run = latestRun(from: runs) {
                WorkflowRunRow(run: run)
            } else {
                Text("No recent runs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            }

            Divider()
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    /// Returns the currently running run, or the most recent completed run.
    private func latestRun(from runs: [WorkflowRun]) -> WorkflowRun? {
        let active = runs.first { $0.status == .inProgress || $0.status == .queued || $0.status == .waiting || $0.status == .pending || $0.status == .requested }
        return active ?? runs.first
    }
}
