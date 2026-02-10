import SwiftUI

@main
struct ActionBarApp: App {
    @State private var appState = AppState()

    init() {
        let state = appState
        Task { @MainActor in
            await state.onLaunch()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(appState)
        } label: {
            StatusMenuBarLabel(workflowRuns: appState.workflowRuns)
        }
        .menuBarExtraStyle(.window)
    }
}
