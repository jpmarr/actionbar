import SwiftUI

struct StatusMenuBarLabel: View {
    let workflowRuns: [Int: [WorkflowRun]]

    var body: some View {
        let info = menuBarInfo
        if info.activeCount > 1 {
            Label("ActionBar — \(info.activeCount) running", systemImage: info.iconName)
        } else {
            Label("ActionBar", systemImage: info.iconName)
        }
    }

    private struct MenuBarInfo {
        let iconName: String
        let activeCount: Int
    }

    private var menuBarInfo: MenuBarInfo {
        let allRuns = workflowRuns.values.flatMap { $0 }
        guard !allRuns.isEmpty else {
            return MenuBarInfo(iconName: "gearshape.arrow.triangle.2.circlepath", activeCount: 0)
        }

        let inProgressCount = allRuns.filter { $0.status == .inProgress }.count
        if inProgressCount > 0 {
            return MenuBarInfo(iconName: "circle.dotted.circle", activeCount: inProgressCount)
        }

        let queuedCount = allRuns.filter {
            $0.status == .queued || $0.status == .waiting || $0.status == .pending || $0.status == .requested
        }.count
        if queuedCount > 0 {
            return MenuBarInfo(iconName: "clock.circle", activeCount: queuedCount)
        }

        // Resting state: base icon on the single most recent run
        guard let latestRun = allRuns.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return MenuBarInfo(iconName: "gearshape.arrow.triangle.2.circlepath", activeCount: 0)
        }

        if latestRun.status == .completed {
            switch latestRun.conclusion {
            case .success:
                return MenuBarInfo(iconName: "checkmark.circle.fill", activeCount: 0)
            case .failure, .startupFailure, .timedOut:
                return MenuBarInfo(iconName: "exclamationmark.circle.fill", activeCount: 0)
            case .cancelled:
                return MenuBarInfo(iconName: "stop.circle.fill", activeCount: 0)
            case .actionRequired:
                return MenuBarInfo(iconName: "exclamationmark.circle.fill", activeCount: 0)
            default:
                return MenuBarInfo(iconName: "checkmark.circle.fill", activeCount: 0)
            }
        }

        return MenuBarInfo(iconName: "gearshape.arrow.triangle.2.circlepath", activeCount: 0)
    }
}
