import Foundation

enum GitBranchError: Error, Sendable {
    case notAGitRepo
    case detachedHead
    case processError(String)

    var localizedDescription: String {
        switch self {
        case .notAGitRepo:
            "Not a git repository."
        case .detachedHead:
            "HEAD is detached (not on a branch)."
        case .processError(let message):
            "Git error: \(message)"
        }
    }
}

enum GitBranchService {
    static func currentBranch(at localPath: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
            process.currentDirectoryURL = URL(fileURLWithPath: localPath)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if proc.terminationStatus != 0 {
                    if output.contains("not a git repository") {
                        continuation.resume(throwing: GitBranchError.notAGitRepo)
                    } else {
                        continuation.resume(throwing: GitBranchError.processError(output))
                    }
                    return
                }

                if output == "HEAD" {
                    continuation.resume(throwing: GitBranchError.detachedHead)
                } else if output.isEmpty {
                    continuation.resume(throwing: GitBranchError.processError("No branch name returned"))
                } else {
                    continuation.resume(returning: output)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GitBranchError.processError(error.localizedDescription))
            }
        }
    }
}
