import Foundation

enum GitHubAPIError: LocalizedError, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(resetDate: Date?)
    case serverError(statusCode: Int, body: String?)
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case noToken
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Authentication required. Please sign in."
        case .forbidden:
            "Access denied. Check your token permissions."
        case .notFound:
            "Resource not found."
        case .rateLimited(let resetDate):
            if let resetDate {
                "Rate limited. Resets at \(resetDate.formatted(date: .omitted, time: .shortened))."
            } else {
                "Rate limited. Please wait."
            }
        case .serverError(let code, let body):
            if let body,
               let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                "GitHub error (\(code)): \(message)"
            } else if let body, !body.isEmpty {
                "GitHub error (\(code)): \(body)"
            } else {
                "GitHub server error (\(code))."
            }
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            "Failed to parse response: \(error.localizedDescription)"
        case .invalidResponse:
            "Invalid response from GitHub."
        case .noToken:
            "No authentication token. Please sign in."
        case .validationFailed(let body):
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                message
            } else {
                "Validation failed: \(body)"
            }
        }
    }
}
