import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var showingLogoutConfirmation = false
    @State private var pendingDeleteSession: Session?
    
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
                if let errorMessage = appState.userFacingError, !errorMessage.isEmpty {
                    InlineErrorBanner(message: errorMessage)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

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
                        .onChange(of: appState.selectedOrg) { _, _ in
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
                            SessionRow(
                                session: session,
                                onResume: { appState.resumeSession(session) },
                                onDeleteRequest: { pendingDeleteSession = session }
                            )
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
                            RepoRow(repo: repo) {
                                await appState.startSession(for: repo)
                            }
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

                        if !appState.isLoading && filteredRepos.isEmpty && appState.userFacingError == nil {
                            HStack {
                                Spacer()
                                Text(searchText.isEmpty ? "No repositories found." : "No repositories match \"\(searchText)\".")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 20)
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
                    .help("Refresh repositories")
                    .accessibilityLabel("Refresh repositories")
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Logout") {
                        showingLogoutConfirmation = true
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
        .alert("Logout?", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                do {
                    try appState.logout()
                } catch {
                    appState.userFacingError = "Failed to logout."
                }
            }
        } message: {
            Text("You will need to sign in again to access repositories.")
        }
        .alert("Delete Session?", isPresented: Binding(
            get: { pendingDeleteSession != nil },
            set: { shouldShow in
                if !shouldShow {
                    pendingDeleteSession = nil
                }
            }
        )) {
            Button("Cancel", role: .cancel) {
                pendingDeleteSession = nil
            }
            Button("Delete", role: .destructive) {
                guard let session = pendingDeleteSession else { return }
                appState.deleteSession(session)
                pendingDeleteSession = nil
            }
        } message: {
            Text("This removes the local session and container reference.")
        }
    }
}

struct RepoRow: View {
    let repo: Repository
    let onOpen: () async -> Void
    
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
                    await onOpen()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await onOpen()
            }
        }
    }
}

struct SessionRow: View {
    let session: Session
    let onResume: () -> Void
    let onDeleteRequest: () -> Void
    
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
                onResume()
            }
            .buttonStyle(.borderedProminent)
            
            Button(role: .destructive) {
                onDeleteRequest()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("Delete session")
            .accessibilityLabel("Delete session")
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            onResume()
        }
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
