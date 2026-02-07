import SwiftUI

struct StatusIcon: View {
    let status: WorkflowRun.Status
    let conclusion: WorkflowRun.Conclusion?

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(color)
            .symbolEffect(.pulse, isActive: isAnimating)
    }

    private var symbolName: String {
        switch status {
        case .completed:
            switch conclusion {
            case .success:
                return "checkmark.circle.fill"
            case .failure, .startupFailure:
                return "xmark.circle.fill"
            case .cancelled:
                return "stop.circle.fill"
            case .skipped:
                return "arrow.right.circle.fill"
            case .timedOut:
                return "clock.badge.exclamationmark.fill"
            case .actionRequired:
                return "exclamationmark.circle.fill"
            default:
                return "circle.fill"
            }
        case .inProgress:
            return "circle.dotted.circle"
        case .queued, .waiting, .pending, .requested:
            return "clock.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .completed:
            switch conclusion {
            case .success:
                return .green
            case .failure, .startupFailure, .timedOut:
                return .red
            case .cancelled:
                return .gray
            case .actionRequired:
                return .orange
            default:
                return .secondary
            }
        case .inProgress:
            return .orange
        case .queued, .waiting, .pending, .requested:
            return .yellow
        case .unknown:
            return .secondary
        }
    }

    private var isAnimating: Bool {
        status == .inProgress
    }
}
