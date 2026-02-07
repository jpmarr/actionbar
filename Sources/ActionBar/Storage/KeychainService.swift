import Foundation

/// Stores the auth token in a file in Application Support.
/// Keychain doesn't work reliably with unsigned SPM binaries (code signature
/// changes on every build), so we use a file-based approach instead.
/// The bundle.sh script produces a signed .app where Keychain would work,
/// but this keeps dev and release behavior consistent.
struct KeychainService: Sendable {
    private let fileURL: URL

    init(service: String = Configuration.keychainServiceName,
         account: String = Configuration.keychainAccountName) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ActionBar", isDirectory: true)
        self.fileURL = dir.appendingPathComponent(".token")
    }

    func save(token: String) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(token.utf8).write(to: fileURL, options: [.atomic, .completeFileProtection])
        // Restrict permissions to owner only
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func retrieve() -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
}
