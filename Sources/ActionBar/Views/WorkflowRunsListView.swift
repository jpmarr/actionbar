import SwiftUI

struct WorkflowRunsListView: View {
    @Environment(AppState.self) private var appState
    @State private var workflowToRemove: WatchedWorkflow?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(appState.watchedWorkflows) { workflow in
                    workflowSection(workflow, isLast: workflow == appState.watchedWorkflows.last)
                }
            }
            .padding(.horizontal)
        }
    }

    private func workflowSection(_ workflow: WatchedWorkflow, isLast: Bool) -> some View {
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
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(branch)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()

                HStack(spacing: 0) {
                    Button {
                        Task { await appState.prepareDispatch(for: workflow) }
                    } label: {
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .help("Trigger run")

                    Button {
                        appState.showDispatchConfig(for: workflow)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .help("Configure dispatch")

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            workflowToRemove = workflow
                        }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .help("Stop watching")
                }
            }
            .buttonStyle(HoverButtonStyle())

            if workflowToRemove == workflow {
                HStack(spacing: 8) {
                    Text("Remove this workflow?")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            workflowToRemove = nil
                        }
                    }
                    .buttonStyle(HoverButtonStyle())
                    .font(.caption2)

                    Button("Remove") {
                        appState.removeWatchedWorkflow(workflow)
                        workflowToRemove = nil
                    }
                    .buttonStyle(HoverButtonStyle())
                    .font(.caption2)
                    .foregroundStyle(.red)
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                let runs = appState.workflowRuns[workflow.workflowId] ?? []
                if let run = latestRun(from: runs) {
                    WorkflowRunRow(run: run)
                } else {
                    Text("No recent runs")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 2)
                }
            }

            if !isLast {
                Divider()
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    /// Returns the currently running run, or the most recent completed run.
    private func latestRun(from runs: [WorkflowRun]) -> WorkflowRun? {
        let active = runs.first { $0.status == .inProgress || $0.status == .queued || $0.status == .waiting || $0.status == .pending || $0.status == .requested }
        return active ?? runs.first
    }
}
