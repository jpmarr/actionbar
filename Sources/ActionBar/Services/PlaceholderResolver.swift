import Foundation

struct Placeholder: Sendable {
    let name: String
    let displayName: String
    let description: String
}

enum PlaceholderResolver {
    static let available: [Placeholder] = [
        Placeholder(
            name: "current_branch",
            displayName: "Current Branch",
            description: "Current git branch of the local repo"
        ),
        Placeholder(
            name: "default_ref",
            displayName: "Default Ref",
            description: "The default branch/ref for this workflow"
        ),
        Placeholder(
            name: "repo_name",
            displayName: "Repository Name",
            description: "The repository name"
        ),
    ]

    static func containsPlaceholder(_ name: String, in value: String) -> Bool {
        value.contains("${\(name)}")
    }

    static func containsAnyPlaceholder(in value: String) -> Bool {
        available.contains { containsPlaceholder($0.name, in: value) }
    }

    static func resolve(_ value: String, context: [String: String]) -> String {
        var result = value
        for (key, replacement) in context {
            result = result.replacingOccurrences(of: "${\(key)}", with: replacement)
        }
        return result
    }

    static func completions(for prefix: String) -> [Placeholder] {
        let lowered = prefix.lowercased()
        if lowered.isEmpty { return available }
        return available.filter { $0.name.lowercased().hasPrefix(lowered) }
    }
}
