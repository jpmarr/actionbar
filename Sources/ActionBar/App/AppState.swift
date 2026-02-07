import SwiftUI
import UserNotifications

enum AuthPhase: Sendable {
    case idle
    case waitingForUserCode(userCode: String, verificationURL: String)
    case polling
    case error(String)
}

@Observable
@MainActor
final class AppState {
    // MARK: - Auth State
    var isSignedIn = false
    var currentUser: GitHubUser?
    var authPhase: AuthPhase = .idle
    var showPATEntry = false
    var patInput = ""

    // MARK: - Data State
    var repositories: [Repository] = []
    var watchedWorkflows: [WatchedWorkflow] = []
    var workflowRuns: [Int: [WorkflowRun]] = [:] // keyed by workflowId

    // MARK: - UI State
    var isLoadingRepos = false
    var isLoadingWorkflows = false
    var errorMessage: String?
    var showingAddWorkflow = false
    var showingSettings = false
    var selectedRepository: Repository?
    var availableWorkflows: [Workflow] = []

    // MARK: - Branch Detection
    var detectedBranches: [String: String] = [:] // workflow id -> branch name

    // MARK: - Dispatch State
    var showingDispatchConfig: WatchedWorkflow?
    var showingDispatch: WatchedWorkflow?
    var isLoadingDispatch = false
    var dispatchError: String?
    var dispatchSuccess = false
    var dispatchInputs: [WorkflowDispatchInput] = []
    var dispatchInputValues: [String: String] = [:]
    var dispatchRef: String = "main"

    // MARK: - Services
    let gitHubClient: GitHubClient
    private let authService: AuthService
    private let keychainService: KeychainService
    private let storageService: StorageService
    let pollingService: PollingService
    let dispatchConfigStorage: DispatchConfigStorage
    let notificationService = NotificationService()
    private let notificationDelegate = NotificationDelegate()
    private var authPollTask: Task<Void, Never>?
    private var previousRunStatuses: [Int: WorkflowRun.Status] = [:]

    init(gitHubClient: GitHubClient = GitHubClient(),
         authService: AuthService = AuthService(),
         keychainService: KeychainService = KeychainService(),
         storageService: StorageService = StorageService(),
         dispatchConfigStorage: DispatchConfigStorage = DispatchConfigStorage()) {
        self.gitHubClient = gitHubClient
        self.authService = authService
        self.keychainService = keychainService
        self.storageService = storageService
        self.pollingService = PollingService(gitHubClient: gitHubClient)
        self.dispatchConfigStorage = dispatchConfigStorage
    }

    // MARK: - Lifecycle

    func onAppear() async {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        await notificationService.requestPermission()
        watchedWorkflows = storageService.load()

        if let token = keychainService.retrieve() {
            await gitHubClient.setToken(token)
            do {
                let user = try await gitHubClient.fetchCurrentUser()
                currentUser = user
                isSignedIn = true
                await restartPolling()
                await refreshDetectedBranches()
            } catch {
                // Token is stale — clear it
                keychainService.delete()
                await gitHubClient.setToken(nil)
            }
        }
    }

    // MARK: - Watched Workflows

    func addWatchedWorkflow(_ workflow: WatchedWorkflow) {
        guard !watchedWorkflows.contains(workflow) else { return }
        watchedWorkflows.append(workflow)
        try? storageService.save(watchedWorkflows)
        Task { await restartPolling() }
    }

    func removeWatchedWorkflow(_ workflow: WatchedWorkflow) {
        watchedWorkflows.removeAll { $0 == workflow }
        workflowRuns.removeValue(forKey: workflow.workflowId)
        try? storageService.save(watchedWorkflows)
        Task { await restartPolling() }
    }

    func restartPolling() async {
        guard isSignedIn, !watchedWorkflows.isEmpty else {
            await pollingService.stop()
            return
        }
        await pollingService.setOnRunsUpdated { [weak self] workflowId, runs in
            Task { @MainActor in
                self?.handleRunsUpdate(workflowId: workflowId, runs: runs)
            }
        }
        await pollingService.start(workflows: watchedWorkflows)
    }

    func refreshNow() async {
        await pollingService.pollOnce(workflows: watchedWorkflows)
        await refreshDetectedBranches()
    }

    // MARK: - Repositories & Workflows

    func fetchRepositories() async {
        isLoadingRepos = true
        errorMessage = nil
        do {
            repositories = try await gitHubClient.fetchRepositories(perPage: 100)
        } catch {
            errorMessage = "Failed to load repos: \(error.localizedDescription)"
        }
        isLoadingRepos = false
    }

    func fetchWorkflows(for repo: Repository) async {
        selectedRepository = repo
        isLoadingWorkflows = true
        availableWorkflows = []
        do {
            let response = try await gitHubClient.fetchWorkflows(owner: repo.owner.login, repo: repo.name)
            availableWorkflows = response.workflows.filter { $0.state == .active }
        } catch {
            errorMessage = "Failed to load workflows: \(error.localizedDescription)"
        }
        isLoadingWorkflows = false
    }

    func isWatching(workflowId: Int) -> Bool {
        watchedWorkflows.contains { $0.workflowId == workflowId }
    }

    func toggleWatch(workflow: Workflow, in repo: Repository) {
        if let existing = watchedWorkflows.first(where: { $0.workflowId == workflow.id }) {
            removeWatchedWorkflow(existing)
        } else {
            let watched = WatchedWorkflow(
                repositoryFullName: repo.fullName,
                repositoryOwner: repo.owner.login,
                repositoryName: repo.name,
                workflowId: workflow.id,
                workflowName: workflow.name
            )
            addWatchedWorkflow(watched)
        }
    }

    // MARK: - Auth: Device Flow

    func startDeviceFlow() async {
        authPhase = .polling
        do {
            let deviceCode = try await authService.requestDeviceCode()
            authPhase = .waitingForUserCode(
                userCode: deviceCode.userCode,
                verificationURL: deviceCode.verificationUri
            )

            authPollTask = Task {
                do {
                    let token = try await authService.pollForToken(
                        deviceCode: deviceCode.deviceCode,
                        interval: deviceCode.interval,
                        expiresIn: deviceCode.expiresIn
                    )
                    await completeSignIn(token: token)
                } catch is CancellationError {
                    authPhase = .idle
                } catch {
                    authPhase = .error(error.localizedDescription)
                }
            }
        } catch {
            authPhase = .error("Failed to start device flow: \(error.localizedDescription)")
        }
    }

    func cancelAuth() {
        authPollTask?.cancel()
        authPollTask = nil
        authPhase = .idle
        showPATEntry = false
        patInput = ""
    }

    // MARK: - Auth: Personal Access Token

    func signInWithPAT() async {
        let token = patInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        await gitHubClient.setToken(token)
        do {
            let user = try await gitHubClient.fetchCurrentUser()
            try keychainService.save(token: token)
            currentUser = user
            isSignedIn = true
            showPATEntry = false
            patInput = ""
            authPhase = .idle
            await restartPolling()
        } catch {
            await gitHubClient.setToken(nil)
            authPhase = .error("Invalid token: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        await pollingService.stop()
        keychainService.delete()
        await gitHubClient.setToken(nil)
        isSignedIn = false
        currentUser = nil
        repositories = []
        watchedWorkflows = []
        workflowRuns = [:]
        authPhase = .idle
    }

    // MARK: - Dispatch

    func showDispatchConfig(for workflow: WatchedWorkflow) {
        showingDispatchConfig = workflow
        showingDispatch = nil
    }

    func cancelDispatchConfig() {
        showingDispatchConfig = nil
    }

    func prepareDispatch(for workflow: WatchedWorkflow) async {
        showingDispatch = workflow
        showingDispatchConfig = nil
        isLoadingDispatch = true
        dispatchError = nil
        dispatchSuccess = false
        dispatchInputs = []
        dispatchInputValues = [:]
        dispatchRef = "main"

        // Load saved config
        let config = dispatchConfigStorage.loadConfig(for: workflow.id)
        if let config {
            dispatchRef = config.defaultRef
        }

        // Fetch workflow YAML and parse inputs
        do {
            // The workflow path is stored in Workflow.path (e.g. ".github/workflows/ci.yml")
            // We need to fetch the runs to get the workflow path, or use the workflow API
            let workflowsResponse = try await gitHubClient.fetchWorkflows(
                owner: workflow.repositoryOwner,
                repo: workflow.repositoryName
            )
            if let wf = workflowsResponse.workflows.first(where: { $0.id == workflow.workflowId }) {
                let yamlContent = try await gitHubClient.fetchWorkflowFileContent(
                    owner: workflow.repositoryOwner,
                    repo: workflow.repositoryName,
                    path: wf.path
                )
                dispatchInputs = WorkflowInputParser.parseInputs(from: yamlContent)

                // Pre-fill defaults from YAML
                for input in dispatchInputs {
                    dispatchInputValues[input.name] = input.defaultValue
                }

                // Override with saved config defaults
                if let config {
                    for (name, inputDefault) in config.inputDefaults {
                        if inputDefault.useCurrentBranch, let path = config.localRepoPath {
                            if let branch = try? await GitBranchService.currentBranch(at: path) {
                                dispatchInputValues[name] = branch
                            }
                        } else if !inputDefault.value.isEmpty {
                            dispatchInputValues[name] = inputDefault.value
                        }
                    }
                }
            }
        } catch {
            dispatchError = "Failed to load workflow inputs: \(error.localizedDescription)"
        }

        isLoadingDispatch = false
    }

    func executeDispatch() async {
        guard let workflow = showingDispatch else { return }
        guard !dispatchRef.trimmingCharacters(in: .whitespaces).isEmpty else {
            dispatchError = "Branch/ref is required."
            return
        }

        isLoadingDispatch = true
        dispatchError = nil

        do {
            try await gitHubClient.triggerWorkflowDispatch(
                owner: workflow.repositoryOwner,
                repo: workflow.repositoryName,
                workflowId: workflow.workflowId,
                ref: dispatchRef,
                inputs: dispatchInputValues
            )
            dispatchSuccess = true
            // Refresh runs after a short delay to pick up the new run
            Task {
                try? await Task.sleep(for: .seconds(3))
                await refreshNow()
            }
        } catch {
            dispatchError = "Dispatch failed: \(error.localizedDescription)"
        }

        isLoadingDispatch = false
    }

    func cancelDispatch() {
        showingDispatch = nil
        dispatchInputs = []
        dispatchInputValues = [:]
        dispatchRef = "main"
        dispatchError = nil
        dispatchSuccess = false
    }

    // MARK: - Branch Detection

    func refreshDetectedBranches() async {
        for workflow in watchedWorkflows {
            guard let config = dispatchConfigStorage.loadConfig(for: workflow.id),
                  let repoPath = config.localRepoPath,
                  !repoPath.isEmpty,
                  config.inputDefaults.values.contains(where: { $0.useCurrentBranch }) else {
                continue
            }
            do {
                let branch = try await GitBranchService.currentBranch(at: repoPath)
                detectedBranches[workflow.id] = branch
            } catch {
                detectedBranches.removeValue(forKey: workflow.id)
            }
        }
    }

    // MARK: - Private

    private func handleRunsUpdate(workflowId: Int, runs: [WorkflowRun]) {
        let oldRuns = workflowRuns[workflowId] ?? []
        workflowRuns[workflowId] = runs

        // Only notify after we have a baseline (not on first load)
        guard !oldRuns.isEmpty else {
            for run in runs {
                previousRunStatuses[run.id] = run.status
            }
            return
        }

        let watched = watchedWorkflows.first { $0.workflowId == workflowId }
        let workflowName = watched?.workflowName ?? "Workflow"
        let repoName = watched?.repositoryFullName ?? ""
        let settings = SettingsStorage()

        for run in runs {
            let previousStatus = previousRunStatuses[run.id]

            if settings.notificationsEnabled {
                // Notify on workflow start
                let isActive = run.status == .inProgress || run.status == .queued
                let wasActive = previousStatus == .inProgress || previousStatus == .queued
                if isActive && !wasActive && previousStatus != nil {
                    Task {
                        await notificationService.sendRunStartedNotification(
                            run: run, workflowName: workflowName, repoName: repoName
                        )
                    }
                }
                // Also notify for brand new runs (no previous status)
                if isActive && previousStatus == nil {
                    Task {
                        await notificationService.sendRunStartedNotification(
                            run: run, workflowName: workflowName, repoName: repoName
                        )
                    }
                }

                // Notify on workflow completion
                if run.status == .completed && previousStatus != nil && previousStatus != .completed {
                    Task {
                        await notificationService.sendRunCompletedNotification(
                            run: run, workflowName: workflowName, repoName: repoName
                        )
                    }
                }
            }

            previousRunStatuses[run.id] = run.status
        }
    }

    private func completeSignIn(token: String) async {
        await gitHubClient.setToken(token)
        do {
            let user = try await gitHubClient.fetchCurrentUser()
            try keychainService.save(token: token)
            currentUser = user
            isSignedIn = true
            authPhase = .idle
            await restartPolling()
        } catch {
            authPhase = .error("Sign in failed: \(error.localizedDescription)")
        }
    }
}
