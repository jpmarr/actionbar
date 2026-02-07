import SwiftUI

struct StatusMenuBarLabel: View {
    let workflowRuns: [Int: [WorkflowRun]]

    var body: some View {
        Label("ActionBar", systemImage: iconName)
    }

    private var iconName: String {
        let allRuns = workflowRuns.values.flatMap { $0 }
        guard !allRuns.isEmpty else {
            return "gearshape.arrow.triangle.2.circlepath"
        }

        let hasFailure = allRuns.contains { run in
            run.status == .completed && (run.conclusion == .failure || run.conclusion == .startupFailure || run.conclusion == .timedOut)
        }
        if hasFailure {
            return "exclamationmark.circle.fill"
        }

        let hasInProgress = allRuns.contains { $0.status == .inProgress }
        if hasInProgress {
            return "circle.dotted.circle"
        }

        let hasQueued = allRuns.contains {
            $0.status == .queued || $0.status == .waiting || $0.status == .pending
        }
        if hasQueued {
            return "clock.circle"
        }

        let allSuccess = allRuns.allSatisfy { run in
            run.status == .completed && run.conclusion == .success
        }
        if allSuccess {
            return "checkmark.circle.fill"
        }

        return "gearshape.arrow.triangle.2.circlepath"
    }
}
