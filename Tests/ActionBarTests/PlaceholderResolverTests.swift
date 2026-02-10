import Foundation
import Testing
@testable import ActionBar

@Suite("PlaceholderResolver")
struct PlaceholderResolverTests {

    @Test("Resolves a single placeholder")
    func resolveSingle() {
        let result = PlaceholderResolver.resolve(
            "${current_branch}",
            context: ["current_branch": "feature/foo"]
        )
        #expect(result == "feature/foo")
    }

    @Test("Resolves multiple placeholders")
    func resolveMultiple() {
        let result = PlaceholderResolver.resolve(
            "${repo_name}:${current_branch}",
            context: ["repo_name": "my-repo", "current_branch": "main"]
        )
        #expect(result == "my-repo:main")
    }

    @Test("Unknown placeholders left intact")
    func unknownLeftIntact() {
        let result = PlaceholderResolver.resolve(
            "${unknown_thing}",
            context: ["current_branch": "main"]
        )
        #expect(result == "${unknown_thing}")
    }

    @Test("No placeholders pass through unchanged")
    func noPlaceholders() {
        let result = PlaceholderResolver.resolve(
            "plain text",
            context: ["current_branch": "main"]
        )
        #expect(result == "plain text")
    }

    @Test("Placeholder embedded in surrounding text")
    func embeddedPlaceholder() {
        let result = PlaceholderResolver.resolve(
            "deploy-${current_branch}-preview",
            context: ["current_branch": "develop"]
        )
        #expect(result == "deploy-develop-preview")
    }

    @Test("containsPlaceholder detects presence")
    func containsPlaceholder() {
        #expect(PlaceholderResolver.containsPlaceholder("current_branch", in: "${current_branch}"))
        #expect(PlaceholderResolver.containsPlaceholder("current_branch", in: "prefix-${current_branch}-suffix"))
        #expect(!PlaceholderResolver.containsPlaceholder("current_branch", in: "no placeholders"))
        #expect(!PlaceholderResolver.containsPlaceholder("current_branch", in: "${default_ref}"))
    }

    @Test("containsAnyPlaceholder")
    func containsAny() {
        #expect(PlaceholderResolver.containsAnyPlaceholder(in: "${current_branch}"))
        #expect(PlaceholderResolver.containsAnyPlaceholder(in: "${repo_name}"))
        #expect(!PlaceholderResolver.containsAnyPlaceholder(in: "plain text"))
    }

    @Test("Completions with prefix filters correctly")
    func completionsWithPrefix() {
        let results = PlaceholderResolver.completions(for: "cur")
        #expect(results.count == 1)
        #expect(results[0].name == "current_branch")
    }

    @Test("Completions with empty prefix returns all")
    func completionsEmpty() {
        let results = PlaceholderResolver.completions(for: "")
        #expect(results.count == PlaceholderResolver.available.count)
    }

    @Test("Completions with no match returns empty")
    func completionsNoMatch() {
        let results = PlaceholderResolver.completions(for: "zzz")
        #expect(results.isEmpty)
    }

    @Test("Completions are case insensitive")
    func completionsCaseInsensitive() {
        let results = PlaceholderResolver.completions(for: "DEF")
        #expect(results.count == 1)
        #expect(results[0].name == "default_ref")
    }

    // MARK: - InputDefault Migration

    @Test("Legacy InputDefault with useCurrentBranch migrates to placeholder")
    func legacyMigration() throws {
        let json = """
        {"value": "", "useCurrentBranch": true}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(InputDefault.self, from: json)
        #expect(decoded.value == "${current_branch}")
    }

    @Test("Legacy InputDefault without flag preserves value")
    func legacyNoFlag() throws {
        let json = """
        {"value": "my-value"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(InputDefault.self, from: json)
        #expect(decoded.value == "my-value")
    }

    @Test("Legacy InputDefault with flag false preserves value")
    func legacyFlagFalse() throws {
        let json = """
        {"value": "my-value", "useCurrentBranch": false}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(InputDefault.self, from: json)
        #expect(decoded.value == "my-value")
    }

    @Test("InputDefault encodes without legacy key")
    func encodesClean() throws {
        let input = InputDefault(value: "${current_branch}")
        let data = try JSONEncoder().encode(input)
        let json = String(data: data, encoding: .utf8)!
        #expect(!json.contains("useCurrentBranch"))
        #expect(json.contains("current_branch"))
    }
}
