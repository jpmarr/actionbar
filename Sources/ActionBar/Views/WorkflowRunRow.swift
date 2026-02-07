import SwiftUI

struct WorkflowRunRow: View {
    let run: WorkflowRun

    var body: some View {
        Button {
            if let url = URL(string: run.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                StatusIcon(status: run.status, conclusion: run.conclusion)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(run.headBranch ?? "unknown")
                        .font(.system(.caption, weight: .medium))
                        .lineLimit(1)

                    Text("#\(run.runNumber) \(run.event)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(run.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
