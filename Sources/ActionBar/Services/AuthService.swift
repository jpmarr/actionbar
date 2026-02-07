import Foundation

actor AuthService {
    private let session: URLSession
    private let clientId: String

    enum AuthError: Error, Sendable {
        case deviceCodeRequestFailed
        case tokenPollExpired
        case tokenDenied(String)
        case networkError(Error)
        case unexpectedResponse
    }

    init(session: URLSession = .shared, clientId: String = Configuration.gitHubClientId) {
        self.session = session
        self.clientId = clientId
    }

    /// Step 1: Request a device code from GitHub
    func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: Configuration.deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonBody: [String: String] = [
            "client_id": clientId,
            "scope": Configuration.gitHubScopes
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.deviceCodeRequestFailed
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    /// Step 2: Poll for the access token until the user completes authorization
    func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> String {
        let pollInterval = max(interval, 5)
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))

        while Date() < deadline {
            try await Task.sleep(for: .seconds(pollInterval))

            if Task.isCancelled { throw CancellationError() }

            var request = URLRequest(url: Configuration.accessTokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            request.httpBody = Data(body.utf8)

            let (data, _) = try await session.data(for: request)
            let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)

            if let token = tokenResponse.accessToken {
                return token
            }

            if let error = tokenResponse.error {
                switch error {
                case "authorization_pending":
                    continue
                case "slow_down":
                    try await Task.sleep(for: .seconds(5))
                    continue
                case "expired_token":
                    throw AuthError.tokenPollExpired
                case "access_denied":
                    throw AuthError.tokenDenied("User denied authorization")
                default:
                    throw AuthError.tokenDenied(tokenResponse.errorDescription ?? error)
                }
            }
        }

        throw AuthError.tokenPollExpired
    }
}
