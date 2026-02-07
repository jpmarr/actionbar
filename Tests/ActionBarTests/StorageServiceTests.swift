import Foundation
import Testing
@testable import ActionBar

struct StorageServiceTests {
    private func makeTempService() -> (StorageService, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let service = StorageService(directory: dir)
        return (service, dir)
    }

    @Test func roundTrip() throws {
        let (service, dir) = makeTempService()
        defer { try? FileManager.default.removeItem(at: dir) }

        let workflows = [
            WatchedWorkflow(
                repositoryFullName: "octocat/repo",
                repositoryOwner: "octocat",
                repositoryName: "repo",
                workflowId: 42,
                workflowName: "CI"
            ),
            WatchedWorkflow(
                repositoryFullName: "octocat/repo",
                repositoryOwner: "octocat",
                repositoryName: "repo",
                workflowId: 99,
                workflowName: "Deploy"
            ),
        ]

        try service.save(workflows)
        let loaded = service.load()
        #expect(loaded.count == 2)
        #expect(loaded[0].workflowId == 42)
        #expect(loaded[1].workflowName == "Deploy")
    }

    @Test func loadEmpty() {
        let (service, dir) = makeTempService()
        defer { try? FileManager.default.removeItem(at: dir) }

        let loaded = service.load()
        #expect(loaded.isEmpty)
    }

    @Test func deleteAll() throws {
        let (service, dir) = makeTempService()
        defer { try? FileManager.default.removeItem(at: dir) }

        let workflows = [
            WatchedWorkflow(
                repositoryFullName: "octocat/repo",
                repositoryOwner: "octocat",
                repositoryName: "repo",
                workflowId: 42,
                workflowName: "CI"
            ),
        ]

        try service.save(workflows)
        #expect(service.load().count == 1)

        service.deleteAll()
        #expect(service.load().isEmpty)
    }
}
