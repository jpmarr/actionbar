import Foundation
import Testing
@testable import ActionBar

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.mockHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite(.serialized)
struct GitHubClientTests {
    private func makeClient() -> GitHubClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return GitHubClient(session: session)
    }

    private func mockResponse(
        statusCode: Int = 200,
        json: String,
        headers: [String: String] = [:]
    ) -> (HTTPURLResponse, Data) {
        var allHeaders = ["Content-Type": "application/json"]
        allHeaders.merge(headers) { _, new in new }
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: allHeaders
        )!
        return (response, Data(json.utf8))
    }

    @Test func fetchCurrentUser() async throws {
        let client = makeClient()
        await client.setToken("test-token")

        MockURLProtocol.mockHandler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return self.mockResponse(json: """
                {"login": "octocat", "id": 1, "avatar_url": "https://example.com/avatar.png", "name": "Octocat"}
            """)
        }

        let user = try await client.fetchCurrentUser()
        #expect(user.login == "octocat")
        #expect(user.id == 1)
    }

    @Test func fetchRepositories() async throws {
        let client = makeClient()
        await client.setToken("test-token")

        MockURLProtocol.mockHandler = { _ in
            self.mockResponse(json: """
                [{"id": 1, "name": "repo1", "full_name": "octocat/repo1", "private": false,
                  "html_url": "https://github.com/octocat/repo1",
                  "owner": {"login": "octocat", "id": 1, "avatar_url": "https://example.com/a.png"}}]
            """)
        }

        let repos = try await client.fetchRepositories()
        #expect(repos.count == 1)
        #expect(repos[0].name == "repo1")
    }

    @Test func fetchWorkflows() async throws {
        let client = makeClient()
        await client.setToken("test-token")

        MockURLProtocol.mockHandler = { _ in
            self.mockResponse(json: """
                {"total_count": 1, "workflows": [
                    {"id": 42, "name": "CI", "path": ".github/workflows/ci.yml",
                     "state": "active", "html_url": "https://github.com/o/r/actions/workflows/ci.yml"}
                ]}
            """)
        }

        let response = try await client.fetchWorkflows(owner: "octocat", repo: "repo1")
        #expect(response.totalCount == 1)
        #expect(response.workflows[0].name == "CI")
    }

    @Test func fetchWorkflowRuns() async throws {
        let client = makeClient()
        await client.setToken("test-token")

        MockURLProtocol.mockHandler = { _ in
            self.mockResponse(json: """
                {"total_count": 1, "workflow_runs": [
                    {"id": 100, "name": "CI", "head_branch": "main", "head_sha": "abc",
                     "status": "completed", "conclusion": "success", "workflow_id": 42,
                     "html_url": "https://github.com/o/r/actions/runs/100",
                     "created_at": "2025-01-15T10:00:00Z", "updated_at": "2025-01-15T10:05:00Z",
                     "run_number": 1, "event": "push"}
                ]}
            """)
        }

        let response = try await client.fetchWorkflowRuns(owner: "octocat", repo: "repo1", workflowId: 42)
        #expect(response.totalCount == 1)
        #expect(response.workflowRuns[0].status == .completed)
    }

    @Test func noTokenThrows() async {
        let client = makeClient()

        MockURLProtocol.mockHandler = nil

        await #expect(throws: GitHubAPIError.self) {
            try await client.fetchCurrentUser()
        }
    }

    @Test func unauthorizedThrows() async {
        let client = makeClient()
        await client.setToken("bad-token")

        MockURLProtocol.mockHandler = { _ in
            self.mockResponse(statusCode: 401, json: "{\"message\": \"Bad credentials\"}")
        }

        await #expect(throws: GitHubAPIError.self) {
            try await client.fetchCurrentUser()
        }
    }

    @Test func rateLimitedThrows() async {
        let client = makeClient()
        await client.setToken("test-token")

        MockURLProtocol.mockHandler = { _ in
            self.mockResponse(
                statusCode: 403,
                json: "{\"message\": \"API rate limit exceeded\"}",
                headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1700000000"]
            )
        }

        await #expect(throws: GitHubAPIError.self) {
            try await client.fetchCurrentUser()
        }
    }

    @Test func notFoundThrows() async {
        let client = makeClient()
        await client.setToken("test-token")

        MockURLProtocol.mockHandler = { _ in
            self.mockResponse(statusCode: 404, json: "{\"message\": \"Not Found\"}")
        }

        await #expect(throws: GitHubAPIError.self) {
            try await client.fetchWorkflows(owner: "no", repo: "exist")
        }
    }
}
