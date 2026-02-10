import Foundation

actor PollingService {
    private let gitHubClient: GitHubClient
    private var pollTask: Task<Void, Never>?
    private var baseInterval: TimeInterval
    private var activeInterval: TimeInterval
    private var hasActiveRuns = false

    private var onRunsUpdated: (@Sendable (_ workflowId: Int, _ runs: [WorkflowRun]) -> Void)?

    func setOnRunsUpdated(_ handler: (@Sendable (_ workflowId: Int, _ runs: [WorkflowRun]) -> Void)?) {
        self.onRunsUpdated = handler
    }

    init(gitHubClient: GitHubClient, interval: TimeInterval = Configuration.defaultPollInterval, activeInterval: TimeInterval = Configuration.defaultActivePollInterval) {
        self.gitHubClient = gitHubClient
        self.baseInterval = interval
        self.activeInterval = activeInterval
    }

    func setInterval(_ newInterval: TimeInterval) {
        self.baseInterval = max(newInterval, 10)
    }

    func setActiveInterval(_ newInterval: TimeInterval) {
        self.activeInterval = max(newInterval, 5)
    }

    private var effectiveInterval: TimeInterval {
        hasActiveRuns ? activeInterval : baseInterval
    }

    func start(workflows: [WatchedWorkflow]) {
        stop()
        guard !workflows.isEmpty else { return }

        pollTask = Task { [weak self] in
            await self?.pollAll(workflows: workflows)

            while !Task.isCancelled {
                guard let self else { return }
                let sleepInterval = await self.effectiveInterval
                try? await Task.sleep(for: .seconds(sleepInterval))
                if Task.isCancelled { return }
                await self.pollAll(workflows: workflows)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollOnce(workflows: [WatchedWorkflow]) async {
        await pollAll(workflows: workflows)
    }

    private func pollAll(workflows: [WatchedWorkflow]) async {
        var anyActive = false
        await withTaskGroup(of: Bool.self) { group in
            for workflow in workflows {
                group.addTask { [weak self] in
                    guard let self else { return false }
                    return await self.pollWorkflow(workflow)
                }
            }
            for await isActive in group {
                if isActive { anyActive = true }
            }
        }
        hasActiveRuns = anyActive
    }

    /// Returns true if there are active (non-completed) runs.
    private func pollWorkflow(_ workflow: WatchedWorkflow) async -> Bool {
        do {
            let response = try await gitHubClient.fetchWorkflowRuns(
                owner: workflow.repositoryOwner,
                repo: workflow.repositoryName,
                workflowId: workflow.workflowId,
                perPage: 5
            )
            onRunsUpdated?(workflow.workflowId, response.workflowRuns)
            return response.workflowRuns.contains {
                $0.status == .inProgress || $0.status == .queued || $0.status == .waiting || $0.status == .pending
            }
        } catch {
            return false
        }
    }
}
