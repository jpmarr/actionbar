import SwiftUI

@main
struct ActionBarApp: App {
    @State private var appState = AppState()

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
