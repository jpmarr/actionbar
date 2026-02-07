import SwiftUI

struct RepositoryListView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    appState.showingAddWorkflow = false
                    appState.selectedRepository = nil
                    appState.availableWorkflows = []
                } label: {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                Text("Add Workflow")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            TextField("Search repositories...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)

            if appState.isLoadingRepos {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredRepos) { repo in
                            Button {
                                Task { await appState.fetchWorkflows(for: repo) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(repo.name)
                                            .font(.system(.caption, weight: .medium))
                                        Text(repo.owner.login)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .task {
            await appState.fetchRepositories()
        }
    }

    private var filteredRepos: [Repository] {
        if searchText.isEmpty {
            return appState.repositories
        }
        let query = searchText.lowercased()
        return appState.repositories.filter {
            $0.fullName.lowercased().contains(query)
        }
    }
}
