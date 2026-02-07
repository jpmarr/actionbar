import Foundation

struct WorkflowRun: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let name: String
    let headBranch: String?
    let headSha: String
    let status: Status
    let conclusion: Conclusion?
    let workflowId: Int
    let htmlUrl: String
    let createdAt: Date
    let updatedAt: Date
    let runNumber: Int
    let runAttempt: Int?
    let event: String

    enum Status: String, Codable, Sendable {
        case queued
        case inProgress = "in_progress"
        case completed
        case waiting
        case requested
        case pending
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = Status(rawValue: value) ?? .unknown
        }
    }

    enum Conclusion: String, Codable, Sendable {
        case success
        case failure
        case cancelled
        case skipped
        case timedOut = "timed_out"
        case actionRequired = "action_required"
        case neutral
        case stale
        case startupFailure = "startup_failure"
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = Conclusion(rawValue: value) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, event
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case workflowId = "workflow_id"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runNumber = "run_number"
        case runAttempt = "run_attempt"
    }
}
