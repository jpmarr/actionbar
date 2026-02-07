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
        .task {
            await appState.onAppear()
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        if let workflow = appState.showingDispatchConfig {
            DispatchConfigView(workflow: workflow)
        } else if let workflow = appState.showingDispatch {
            DispatchView(workflow: workflow)
        } else if appState.showingSettings {
            SettingsView()
        } else if appState.showingAddWorkflow {
            addWorkflowFlow
                .frame(minWidth: 480, maxWidth: 480, minHeight: 300, maxHeight: 400)
        } else {
            mainContent
                .frame(minWidth: 480, maxWidth: 480, minHeight: 200)
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            if let error = appState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
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
                        .font(.subheadline)
                    Text("Click + to add workflows")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                Spacer()
            } else {
                WorkflowRunsListView()
            }

            Divider()
            FooterView()
        }
    }
}
