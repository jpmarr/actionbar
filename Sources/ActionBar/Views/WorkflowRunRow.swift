import SwiftUI

struct WorkflowRunRow: View {
    let run: WorkflowRun
    var onTrigger: (() -> Void)?

    @State private var isIconHovered = false

    private var isRunActive: Bool {
        switch run.status {
        case .inProgress, .queued, .waiting, .pending, .requested:
            return true
        default:
            return false
        }
    }

    /// Only allow hover-to-trigger when the run is not already active.
    private var canTrigger: Bool {
        !isRunActive && onTrigger != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if isIconHovered && canTrigger, let onTrigger {
                    onTrigger()
                } else if let url = URL(string: run.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Group {
                    if isIconHovered && canTrigger {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    } else {
                        StatusIcon(status: run.status, conclusion: run.conclusion)
                    }
                }
                .font(.body)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
                .onHover { isIconHovered = $0 }
            }
            .buttonStyle(.plain)
            .help(isIconHovered && canTrigger ? "Trigger run" : "Open in browser")

            Button {
                if let url = URL(string: run.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.headBranch ?? "unknown")
                            .font(.system(.body, weight: .medium))
                            .lineLimit(1)

                        Text("#\(run.runNumber) \(run.event)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(run.updatedAt, style: .relative)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
