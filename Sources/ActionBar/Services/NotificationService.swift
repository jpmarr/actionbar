import Foundation
import UserNotifications

actor NotificationService {
    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false

    func requestPermission() async {
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            isAuthorized = false
        }
    }

    func sendRunStartedNotification(run: WorkflowRun, workflowName: String, repoName: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Workflow Started"
        content.body = "\(workflowName) in \(repoName) — #\(run.runNumber) (\(run.headBranch ?? "unknown"))"
        content.sound = .default
        content.userInfo = ["url": run.htmlUrl]

        let request = UNNotificationRequest(
            identifier: "run-started-\(run.id)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    func sendRunCompletedNotification(run: WorkflowRun, workflowName: String, repoName: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: run)
        content.body = "\(workflowName) in \(repoName) — #\(run.runNumber) (\(run.headBranch ?? "unknown"))"
        content.sound = .default
        content.userInfo = ["url": run.htmlUrl]

        let request = UNNotificationRequest(
            identifier: "run-completed-\(run.id)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    private func notificationTitle(for run: WorkflowRun) -> String {
        switch run.conclusion {
        case .success:
            return "Workflow Succeeded"
        case .failure:
            return "Workflow Failed"
        case .cancelled:
            return "Workflow Cancelled"
        case .timedOut:
            return "Workflow Timed Out"
        case .actionRequired:
            return "Action Required"
        default:
            return "Workflow Completed"
        }
    }
}
