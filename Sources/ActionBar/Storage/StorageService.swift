import Foundation

struct StorageService: Sendable {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ActionBar", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("watched-workflows.json")
    }

    func load() -> [WatchedWorkflow] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([WatchedWorkflow].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ workflows: [WatchedWorkflow]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(workflows)
        try data.write(to: fileURL, options: .atomic)
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
