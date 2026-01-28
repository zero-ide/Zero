import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    
    var filteredRepos: [Repository] {
        if searchText.isEmpty {
            return appState.repositories
        }
        return appState.repositories.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                // Active Sessions
                if !appState.sessions.isEmpty {
                    Section {
                        ForEach(appState.sessions) { session in
                            SessionRow(session: session)
                        }
                    } header: {
                        Text("Active Sessions")
                            .font(.headline)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                
                // Repositories
                Section {
                    List(filteredRepos) { repo in
                        RepoRow(repo: repo)
                    }
                } header: {
                    Text("Repositories")
                        .font(.headline)
                        .padding(.horizontal)
                }
            }
            .searchable(text: $searchText, prompt: "Search repositories...")
            .navigationTitle("Zero")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await appState.fetchRepositories() }}) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Logout") {
                        try? appState.logout()
                    }
                }
            }
        } detail: {
            Text("Select a repository")
                .foregroundStyle(.secondary)
        }
        .task {
            await appState.fetchRepositories()
            appState.loadSessions()
        }
    }
}

struct RepoRow: View {
    let repo: Repository
    
    var body: some View {
        HStack {
            Image(systemName: repo.isPrivate ? "lock" : "globe")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading) {
                Text(repo.name)
                    .fontWeight(.medium)
                Text(repo.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Open") {
                // TODO: 컨테이너 생성 로직
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

struct SessionRow: View {
    let session: Session
    
    var body: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.green)
            
            VStack(alignment: .leading) {
                Text(session.repoURL.lastPathComponent.replacingOccurrences(of: ".git", with: ""))
                    .fontWeight(.medium)
                Text("Last active: \(session.lastActiveAt.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Resume") {
                // TODO: 세션 재개 로직
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}
