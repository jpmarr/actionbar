import Foundation
import Testing
@testable import ActionBar

struct SmeeServiceTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Smee Wrapper with Body as JSON Object

    @Test func parsesSmeeWrapperWithObjectBody() {
        let data = """
        {
            "body": {
                "action": "completed",
                "workflow_run": {
                    "id": 100,
                    "name": "CI",
                    "head_branch": "main",
                    "head_sha": "abc123",
                    "status": "completed",
                    "conclusion": "success",
                    "workflow_id": 42,
                    "html_url": "https://github.com/octocat/repo/actions/runs/100",
                    "created_at": "2025-01-15T10:00:00Z",
                    "updated_at": "2025-01-15T10:05:00Z",
                    "run_number": 1,
                    "event": "push"
                },
                "repository": {
                    "full_name": "octocat/repo"
                }
            }
        }
        """

        let event = SmeeService.parseWebhookEvent(from: data, decoder: decoder)
        #expect(event != nil)
        #expect(event?.action == "completed")
        #expect(event?.workflowRun.id == 100)
        #expect(event?.workflowRun.status == .completed)
        #expect(event?.workflowRun.conclusion == .success)
        #expect(event?.repositoryFullName == "octocat/repo")
    }

    // MARK: - Smee Wrapper with Body as JSON String (Double-Encoded)

    @Test func parsesSmeeWrapperWithStringBody() {
        let innerPayload = """
        {"action":"in_progress","workflow_run":{"id":200,"name":"Deploy","head_branch":"main","head_sha":"def456","status":"in_progress","conclusion":null,"workflow_id":55,"html_url":"https://github.com/octocat/repo/actions/runs/200","created_at":"2025-01-15T12:00:00Z","updated_at":"2025-01-15T12:01:00Z","run_number":5,"event":"push"},"repository":{"full_name":"octocat/repo"}}
        """
        let escaped = innerPayload
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "")

        let data = """
        {"body": "\(escaped)"}
        """

        let event = SmeeService.parseWebhookEvent(from: data, decoder: decoder)
        #expect(event != nil)
        #expect(event?.action == "in_progress")
        #expect(event?.workflowRun.id == 200)
        #expect(event?.workflowRun.status == .inProgress)
        #expect(event?.repositoryFullName == "octocat/repo")
    }

    // MARK: - Non-Workflow Events

    @Test func ignoresNonWorkflowEvent() {
        let data = """
        {
            "body": {
                "action": "opened",
                "pull_request": {
                    "id": 999,
                    "title": "Some PR"
                },
                "repository": {
                    "full_name": "octocat/repo"
                }
            }
        }
        """

        let event = SmeeService.parseWebhookEvent(from: data, decoder: decoder)
        #expect(event == nil)
    }

    // MARK: - Malformed Payloads

    @Test func handlesMalformedJSON() {
        let event = SmeeService.parseWebhookEvent(from: "not json at all", decoder: decoder)
        #expect(event == nil)
    }

    @Test func handlesEmptyBody() {
        let data = """
        {"body": null}
        """
        let event = SmeeService.parseWebhookEvent(from: data, decoder: decoder)
        #expect(event == nil)
    }

    @Test func handlesEmptyString() {
        let event = SmeeService.parseWebhookEvent(from: "", decoder: decoder)
        #expect(event == nil)
    }

    @Test func handlesMissingRepository() {
        let data = """
        {
            "body": {
                "action": "completed",
                "workflow_run": {
                    "id": 100,
                    "name": "CI",
                    "head_branch": "main",
                    "head_sha": "abc123",
                    "status": "completed",
                    "conclusion": "success",
                    "workflow_id": 42,
                    "html_url": "https://github.com/octocat/repo/actions/runs/100",
                    "created_at": "2025-01-15T10:00:00Z",
                    "updated_at": "2025-01-15T10:05:00Z",
                    "run_number": 1,
                    "event": "push"
                }
            }
        }
        """

        let event = SmeeService.parseWebhookEvent(from: data, decoder: decoder)
        #expect(event == nil)
    }

    // MARK: - Ping Events (Smee sends these)

    @Test func ignoresPingEvent() {
        let data = """
        {"body": {"zen": "Anything added dilutes everything else.", "hook_id": 123}}
        """
        let event = SmeeService.parseWebhookEvent(from: data, decoder: decoder)
        #expect(event == nil)
    }
}
