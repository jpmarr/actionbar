import SwiftUI

struct MenuContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.isSignedIn {
                signedInContent
            } else {
                AuthView()
            }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: activeScreen)
        .task {
            await appState.onAppear()
        }
    }

    /// Identifies which screen is currently showing, for driving transitions.
    private var activeScreen: String {
        if !appState.isSignedIn { return "auth" }
        if appState.showingDispatchConfig != nil { return "dispatchConfig" }
        if appState.showingDispatch != nil { return "dispatch" }
        if appState.showingSettings { return "settings" }
        if appState.showingAddWorkflow {
            return appState.selectedRepository != nil ? "workflowPicker" : "repoList"
        }
        return "main"
    }

    /// Sub-views slide in from the trailing edge; main list slides in from the leading edge.
    private static let pushIn: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .trailing)
    )
    private static let popIn: AnyTransition = .asymmetric(
        insertion: .move(edge: .leading),
        removal: .move(edge: .leading)
    )

    @ViewBuilder
    private var signedInContent: some View {
        if let workflow = appState.showingDispatchConfig {
            DispatchConfigView(workflow: workflow)
                .frame(width: 640, height: 520)
                .transition(Self.pushIn)
        } else if let workflow = appState.showingDispatch {
            DispatchView(workflow: workflow)
                .frame(width: 640, height: 520)
                .transition(Self.pushIn)
        } else if appState.showingSettings {
            SettingsView()
                .frame(width: 640, height: 520)
                .transition(Self.pushIn)
        } else if appState.showingAddWorkflow {
            addWorkflowFlow
                .frame(width: 640, height: 520)
                .transition(Self.pushIn)
        } else {
            mainContent
                .frame(width: 640, height: 520)
                .transition(Self.popIn)
        }
    }

    @ViewBuilder
    private var addWorkflowFlow: some View {
        if let repo = appState.selectedRepository {
            WorkflowPickerView(repository: repo)
        } else {
            RepositoryListView()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let user = appState.currentUser {
                HStack {
                    Text("ActionBar")
                        .font(.headline)
                    Spacer()
                    Text(user.login)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    MenuWithHover {
                        Button("Settings...") {
                            appState.showingSettings = true
                        }
                        Divider()
                        Button("Sign Out") {
                            Task { await appState.signOut() }
                        }
                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                    } label: {
                        Text("⋮")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            if let error = appState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.body)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            Divider()

            if appState.watchedWorkflows.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No workflows watched")
                        .foregroundStyle(.secondary)
                        .font(.body)
                    Text("Click + to add workflows")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                }
                Spacer()
            } else {
                WorkflowRunsListView()
                Spacer(minLength: 0)
            }

            Divider()
            FooterView()
        }
    }
}
