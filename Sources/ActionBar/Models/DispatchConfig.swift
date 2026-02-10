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

    init(value: String = "") {
        self.value = value
    }

    // MARK: - Backwards Compatibility

    private enum CodingKeys: String, CodingKey {
        case value
        case useCurrentBranch // read-only for migration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var rawValue = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        let legacy = try container.decodeIfPresent(Bool.self, forKey: .useCurrentBranch) ?? false

        if legacy && !rawValue.contains("${current_branch}") {
            rawValue = "${current_branch}"
        }

        self.value = rawValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
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
