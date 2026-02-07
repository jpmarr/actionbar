import Foundation

struct DispatchConfig: Codable, Sendable {
    let workflowKey: String // WatchedWorkflow.id (e.g. "owner/repo/123")
    var defaultRef: String
    var localRepoPath: String?
    var inputDefaults: [String: InputDefault]

    init(workflowKey: String, defaultRef: String = "main", localRepoPath: String? = nil, inputDefaults: [String: InputDefault] = [:]) {
        self.workflowKey = workflowKey
        self.defaultRef = defaultRef
        self.localRepoPath = localRepoPath
        self.inputDefaults = inputDefaults
    }
}

struct InputDefault: Codable, Sendable {
    var value: String
    var useCurrentBranch: Bool

    init(value: String = "", useCurrentBranch: Bool = false) {
        self.value = value
        self.useCurrentBranch = useCurrentBranch
    }
}

struct WorkflowDispatchInput: Sendable, Identifiable {
    let name: String
    let description: String
    let required: Bool
    let type: InputType
    let defaultValue: String
    let options: [String]

    var id: String { name }

    enum InputType: String, Sendable {
        case string
        case boolean
        case choice
        case number
        case environment
    }
}
