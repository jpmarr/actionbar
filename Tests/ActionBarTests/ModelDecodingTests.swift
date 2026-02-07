import Foundation
import Testing
@testable import ActionBar

struct ModelDecodingTests {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test func decodeRepository() throws {
        let json = """
        {
            "id": 12345,
            "name": "my-repo",
            "full_name": "octocat/my-repo",
            "private": false,
            "html_url": "https://github.com/octocat/my-repo",
            "owner": {
                "login": "octocat",
                "id": 1,
                "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4"
            }
        }
        """
        let repo = try decoder.decode(Repository.self, from: Data(json.utf8))
        #expect(repo.id == 12345)
        #expect(repo.name == "my-repo")
        #expect(repo.fullName == "octocat/my-repo")
        #expect(repo.isPrivate == false)
        #expect(repo.owner.login == "octocat")
    }

    @Test func decodeWorkflow() throws {
        let json = """
        {
            "id": 42,
            "name": "CI",
            "path": ".github/workflows/ci.yml",
            "state": "active",
            "html_url": "https://github.com/octocat/my-repo/actions/workflows/ci.yml"
        }
        """
        let workflow = try decoder.decode(Workflow.self, from: Data(json.utf8))
        #expect(workflow.id == 42)
        #expect(workflow.name == "CI")
        #expect(workflow.state == .active)
    }

    @Test func decodeWorkflowWithUnknownState() throws {
        let json = """
        {
            "id": 42,
            "name": "CI",
            "path": ".github/workflows/ci.yml",
            "state": "something_new",
            "html_url": "https://github.com/octocat/my-repo/actions/workflows/ci.yml"
        }
        """
        let workflow = try decoder.decode(Workflow.self, from: Data(json.utf8))
        #expect(workflow.state == .unknown)
    }

    @Test func decodeWorkflowRun() throws {
        let json = """
        {
            "id": 100,
            "name": "CI",
            "head_branch": "main",
            "head_sha": "abc123",
            "status": "completed",
            "conclusion": "success",
            "workflow_id": 42,
            "html_url": "https://github.com/octocat/my-repo/actions/runs/100",
            "created_at": "2025-01-15T10:00:00Z",
            "updated_at": "2025-01-15T10:05:00Z",
            "run_number": 5,
            "run_attempt": 1,
            "event": "push"
        }
        """
        let run = try decoder.decode(WorkflowRun.self, from: Data(json.utf8))
        #expect(run.id == 100)
        #expect(run.status == .completed)
        #expect(run.conclusion == .success)
        #expect(run.workflowId == 42)
        #expect(run.headBranch == "main")
        #expect(run.runNumber == 5)
    }

    @Test func decodeWorkflowRunInProgress() throws {
        let json = """
        {
            "id": 101,
            "name": "Deploy",
            "head_branch": "feature",
            "head_sha": "def456",
            "status": "in_progress",
            "conclusion": null,
            "workflow_id": 43,
            "html_url": "https://github.com/octocat/my-repo/actions/runs/101",
            "created_at": "2025-01-15T11:00:00Z",
            "updated_at": "2025-01-15T11:02:00Z",
            "run_number": 12,
            "event": "pull_request"
        }
        """
        let run = try decoder.decode(WorkflowRun.self, from: Data(json.utf8))
        #expect(run.status == .inProgress)
        #expect(run.conclusion == nil)
        #expect(run.runAttempt == nil)
    }

    @Test func decodeWorkflowsResponse() throws {
        let json = """
        {
            "total_count": 1,
            "workflows": [
                {
                    "id": 42,
                    "name": "CI",
                    "path": ".github/workflows/ci.yml",
                    "state": "active",
                    "html_url": "https://github.com/octocat/my-repo/actions/workflows/ci.yml"
                }
            ]
        }
        """
        let response = try decoder.decode(WorkflowsResponse.self, from: Data(json.utf8))
        #expect(response.totalCount == 1)
        #expect(response.workflows.count == 1)
        #expect(response.workflows[0].name == "CI")
    }

    @Test func decodeWorkflowRunsResponse() throws {
        let json = """
        {
            "total_count": 1,
            "workflow_runs": [
                {
                    "id": 100,
                    "name": "CI",
                    "head_branch": "main",
                    "head_sha": "abc123",
                    "status": "completed",
                    "conclusion": "failure",
                    "workflow_id": 42,
                    "html_url": "https://github.com/octocat/my-repo/actions/runs/100",
                    "created_at": "2025-01-15T10:00:00Z",
                    "updated_at": "2025-01-15T10:05:00Z",
                    "run_number": 5,
                    "event": "push"
                }
            ]
        }
        """
        let response = try decoder.decode(WorkflowRunsResponse.self, from: Data(json.utf8))
        #expect(response.totalCount == 1)
        #expect(response.workflowRuns[0].conclusion == .failure)
    }

    @Test func decodeDeviceCodeResponse() throws {
        let json = """
        {
            "device_code": "3584d83530557fdd1f46af8289938c8ef79f9dc5",
            "user_code": "WDJB-MJHT",
            "verification_uri": "https://github.com/login/device",
            "expires_in": 899,
            "interval": 5
        }
        """
        let response = try decoder.decode(DeviceCodeResponse.self, from: Data(json.utf8))
        #expect(response.userCode == "WDJB-MJHT")
        #expect(response.interval == 5)
    }

    @Test func decodeAccessTokenResponse() throws {
        let json = """
        {
            "access_token": "gho_abc123",
            "token_type": "bearer",
            "scope": "repo,workflow"
        }
        """
        let response = try decoder.decode(AccessTokenResponse.self, from: Data(json.utf8))
        #expect(response.accessToken == "gho_abc123")
        #expect(response.error == nil)
    }

    @Test func decodeAccessTokenPending() throws {
        let json = """
        {
            "error": "authorization_pending",
            "error_description": "The authorization request is still pending."
        }
        """
        let response = try decoder.decode(AccessTokenResponse.self, from: Data(json.utf8))
        #expect(response.accessToken == nil)
        #expect(response.error == "authorization_pending")
    }

    @Test func decodeGitHubUser() throws {
        let json = """
        {
            "login": "octocat",
            "id": 1,
            "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4",
            "name": "The Octocat"
        }
        """
        let user = try decoder.decode(GitHubUser.self, from: Data(json.utf8))
        #expect(user.login == "octocat")
        #expect(user.name == "The Octocat")
    }

    @Test func decodeRepositoriesAsArray() throws {
        let json = """
        [
            {
                "id": 1,
                "name": "repo1",
                "full_name": "octocat/repo1",
                "private": false,
                "html_url": "https://github.com/octocat/repo1",
                "owner": {
                    "login": "octocat",
                    "id": 1,
                    "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4"
                }
            }
        ]
        """
        let response = try decoder.decode(RepositoriesResponse.self, from: Data(json.utf8))
        #expect(response.repositories.count == 1)
        #expect(response.repositories[0].name == "repo1")
    }

    @Test func watchedWorkflowId() {
        let watched = WatchedWorkflow(
            repositoryFullName: "octocat/my-repo",
            repositoryOwner: "octocat",
            repositoryName: "my-repo",
            workflowId: 42,
            workflowName: "CI"
        )
        #expect(watched.id == "octocat/my-repo/42")
    }
}
