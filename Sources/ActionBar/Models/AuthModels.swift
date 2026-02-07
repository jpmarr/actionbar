import Foundation

struct DeviceCodeResponse: Codable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct AccessTokenResponse: Codable, Sendable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?
    let interval: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
        case interval
    }
}

struct GitHubUser: Codable, Sendable {
    let login: String
    let id: Int
    let avatarUrl: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case login, id, name
        case avatarUrl = "avatar_url"
    }
}
