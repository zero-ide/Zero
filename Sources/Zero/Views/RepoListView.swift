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
                // Organization Picker
                if !appState.organizations.isEmpty {
                    HStack {
                        Text("Context")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Organization", selection: $appState.selectedOrg) {
                            Text("Personal").tag(Optional<Organization>.none)
                            ForEach(appState.organizations) { org in
                                Text(org.login).tag(Optional(org))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .onChange(of: appState.selectedOrg) { _ in
                            Task { await appState.fetchRepositories() }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                
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
                    List {
                        ForEach(filteredRepos) { repo in
                            RepoRow(repo: repo)
                                .onAppear {
                                    if searchText.isEmpty && repo.id == filteredRepos.last?.id {
                                        Task { await appState.loadMoreRepositories() }
                                    }
                                }
                        }
                        
                        if appState.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    }
                } header: {
                    Text("Repositories")
                        .font(.headline)
                        .padding(.horizontal)
                }
            }
            .navigationSplitViewColumnWidth(min: 350, ideal: 500, max: 700)
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
            await appState.fetchOrganizations()
            await appState.fetchRepositories()
            appState.loadSessions()
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay(message: appState.loadingMessage)
            }
        }
    }
}

struct RepoRow: View {
    @EnvironmentObject var appState: AppState
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
                Task {
                    await appState.startSession(for: repo)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

struct SessionRow: View {
    @EnvironmentObject var appState: AppState
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
                appState.resumeSession(session)
            }
            .buttonStyle(.borderedProminent)
            
            Button(role: .destructive) {
                appState.deleteSession(session)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                if !message.isEmpty {
                    Text(message)
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
