import Foundation

struct RepositoriesResponse: Codable, Sendable {
    let totalCount: Int?
    let items: [Repository]?

    // The /user/repos endpoint returns a plain array, not a wrapper object.
    // This init supports both array and object responses.
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
            self.items = try container.decodeIfPresent([Repository].self, forKey: .items)
        } else {
            let repos = try [Repository](from: decoder)
            self.totalCount = repos.count
            self.items = repos
        }
    }

    init(totalCount: Int?, items: [Repository]?) {
        self.totalCount = totalCount
        self.items = items
    }

    var repositories: [Repository] {
        items ?? []
    }

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

struct WorkflowsResponse: Codable, Sendable {
    let totalCount: Int
    let workflows: [Workflow]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflows
    }
}

struct WorkflowRunsResponse: Codable, Sendable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}
