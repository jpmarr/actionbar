import Foundation

actor GitHubClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com")!
    private var token: String?

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - Repositories

    func fetchRepositories(page: Int = 1, perPage: Int = 30) async throws -> [Repository] {
        var components = URLComponents(url: baseURL.appendingPathComponent("user/repos"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "type", value: "all"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)"),
        ]
        let data = try await performRequest(url: components.url!)
        return try decode([Repository].self, from: data)
    }

    // MARK: - Workflows

    func fetchWorkflows(owner: String, repo: String) async throws -> WorkflowsResponse {
        let url = baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(owner)
            .appendingPathComponent(repo)
            .appendingPathComponent("actions/workflows")
        let data = try await performRequest(url: url)
        return try decode(WorkflowsResponse.self, from: data)
    }

    // MARK: - Workflow Runs

    func fetchWorkflowRuns(
        owner: String,
        repo: String,
        workflowId: Int? = nil,
        perPage: Int = 10
    ) async throws -> WorkflowRunsResponse {
        var path = "repos/\(owner)/\(repo)/actions"
        if let workflowId {
            path += "/workflows/\(workflowId)"
        }
        path += "/runs"

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "\(perPage)"),
        ]
        let data = try await performRequest(url: components.url!)
        return try decode(WorkflowRunsResponse.self, from: data)
    }

    // MARK: - User

    func fetchCurrentUser() async throws -> GitHubUser {
        let url = baseURL.appendingPathComponent("user")
        let data = try await performRequest(url: url)
        return try decode(GitHubUser.self, from: data)
    }

    // MARK: - Workflow File Content

    func fetchWorkflowFileContent(owner: String, repo: String, path: String, ref: String? = nil) async throws -> String {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("repos")
                .appendingPathComponent(owner)
                .appendingPathComponent(repo)
                .appendingPathComponent("contents")
                .appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if let ref, !ref.isEmpty {
            components.queryItems = [URLQueryItem(name: "ref", value: ref)]
        }
        let data = try await performRequest(url: components.url!, accept: "application/vnd.github.raw+json")
        guard let content = String(data: data, encoding: .utf8) else {
            throw GitHubAPIError.invalidResponse
        }
        return content
    }

    // MARK: - Workflow Dispatch

    func triggerWorkflowDispatch(
        owner: String,
        repo: String,
        workflowId: Int,
        ref: String,
        inputs: [String: String] = [:]
    ) async throws {
        let url = baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(owner)
            .appendingPathComponent(repo)
            .appendingPathComponent("actions/workflows/\(workflowId)/dispatches")

        struct DispatchBody: Encodable {
            let ref: String
            let inputs: [String: String]
        }

        let body = DispatchBody(ref: ref, inputs: inputs)
        try await performPostRequest(url: url, body: body)
    }

    // MARK: - Private

    private func performRequest(url: URL, accept: String = "application/vnd.github+json") async throws -> Data {
        guard let token else {
            throw GitHubAPIError.noToken
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            if httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                let resetTimestamp = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                    .flatMap(TimeInterval.init)
                    .map { Date(timeIntervalSince1970: $0) }
                throw GitHubAPIError.rateLimited(resetDate: resetTimestamp)
            }
            throw GitHubAPIError.forbidden
        case 404:
            throw GitHubAPIError.notFound
        default:
            let body = String(data: data, encoding: .utf8)
            throw GitHubAPIError.serverError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    private func performPostRequest<T: Encodable>(url: URL, body: T) async throws {
        guard let token else {
            throw GitHubAPIError.noToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            throw GitHubAPIError.forbidden
        case 404:
            throw GitHubAPIError.notFound
        case 422:
            let message = String(data: data, encoding: .utf8) ?? "Unknown validation error"
            throw GitHubAPIError.validationFailed(message)
        default:
            let body = String(data: data, encoding: .utf8)
            throw GitHubAPIError.serverError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try jsonDecoder.decode(type, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }
}
