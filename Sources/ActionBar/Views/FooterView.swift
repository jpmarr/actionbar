import SwiftUI

struct FooterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            Button {
                appState.showingAddWorkflow = true
            } label: {
                Image(systemName: "plus.circle")
            }
            .help("Add workflow")

            Button {
                Task { await appState.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh now")

            Button {
                appState.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Spacer()

            Button {
                Task { await appState.signOut() }
            } label: {
                Text("Sign Out")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
