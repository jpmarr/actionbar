import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Sign in to GitHub")
                .font(.headline)

            switch appState.authPhase {
            case .idle:
                signInButtons

            case .waitingForUserCode(let userCode, let verificationURL):
                deviceCodeView(userCode: userCode, verificationURL: verificationURL)

            case .polling:
                ProgressView("Waiting for authorization...")
                    .controlSize(.small)

                Button("Cancel") {
                    appState.cancelAuth()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.body)

                signInButtons
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.body)
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 360)
    }

    private var signInButtons: some View {
        VStack(spacing: 8) {
            Button("Sign in with GitHub") {
                Task { await appState.startDeviceFlow() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Use Personal Access Token...") {
                appState.authPhase = .idle
                appState.showPATEntry = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.body)

            if appState.showPATEntry {
                patEntryView
            }
        }
    }

    private var patEntryView: some View {
        VStack(spacing: 8) {
            SecureField("ghp_...", text: Bindable(appState).patInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Button("Save Token") {
                Task { await appState.signInWithPAT() }
            }
            .disabled(appState.patInput.isEmpty)
        }
    }

    private func deviceCodeView(userCode: String, verificationURL: String) -> some View {
        VStack(spacing: 12) {
            Text("Enter this code on GitHub:")
                .font(.body)
                .foregroundStyle(.secondary)

            Text(userCode)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button("Copy Code & Open GitHub") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                    if let url = URL(string: verificationURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Cancel") {
                appState.cancelAuth()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}
