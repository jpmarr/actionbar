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
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
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
                                    if let count = appState.repoWorkflowCounts[repo.id] {
                                        Text("\(count)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(.quaternary)
                                            .clipShape(Capsule())
                                    }
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
        let withWorkflows = appState.repositories.filter {
            (appState.repoWorkflowCounts[$0.id] ?? 0) > 0
        }
        if searchText.isEmpty {
            return withWorkflows
        }
        let query = searchText.lowercased()
        return withWorkflows.filter {
            $0.fullName.lowercased().contains(query)
        }
    }
}
