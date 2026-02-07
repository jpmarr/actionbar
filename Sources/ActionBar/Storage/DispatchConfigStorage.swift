import Foundation

struct DispatchConfigStorage: Sendable {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ActionBar", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("dispatch-configs.json")
    }

    func load() -> [DispatchConfig] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DispatchConfig].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ configs: [DispatchConfig]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(configs)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadConfig(for workflowKey: String) -> DispatchConfig? {
        load().first { $0.workflowKey == workflowKey }
    }

    func saveConfig(_ config: DispatchConfig) throws {
        var all = load()
        if let index = all.firstIndex(where: { $0.workflowKey == config.workflowKey }) {
            all[index] = config
        } else {
            all.append(config)
        }
        try save(all)
    }
}
