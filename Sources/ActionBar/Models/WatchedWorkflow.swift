import Foundation

struct WatchedWorkflow: Codable, Sendable, Hashable, Identifiable {
    let repositoryFullName: String
    let repositoryOwner: String
    let repositoryName: String
    let workflowId: Int
    let workflowName: String

    var id: String {
        "\(repositoryFullName)/\(workflowId)"
    }
}
