import Foundation

struct Owner: Codable, Sendable, Hashable {
    let login: String
    let id: Int
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
    }
}

struct Repository: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let isPrivate: Bool
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlUrl = "html_url"
    }
}
