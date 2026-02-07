import Foundation

struct Workflow: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let name: String
    let path: String
    let state: State
    let htmlUrl: String

    enum State: String, Codable, Sendable {
        case active
        case disabledManually = "disabled_manually"
        case disabledInactivity = "disabled_inactivity"
        case deletionInProgress = "deletion_in_progress"
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = State(rawValue: value) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, state
        case htmlUrl = "html_url"
    }
}
