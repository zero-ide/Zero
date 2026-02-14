import SwiftUI

struct GitStashView: View {
    @StateObject private var viewModel = GitStashViewModel()
    @State private var stashMessage = ""
    @State private var showingStashAlert = false
    @State private var pendingDropStash: GitStash?
    @State private var pendingPopStash: GitStash?

    let gitService: GitService
    let containerName: String
    var showsHeader: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                // Header
                HStack {
                    Image(systemName: "archivebox")
                        .foregroundColor(.secondary)
                    Text("Stash")
                        .font(.headline)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button {
                        showingStashAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Create stash")
                    .accessibilityLabel("Create stash")
                }
                .padding()

                Divider()
            } else {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Spacer()
                    Button {
                        showingStashAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Create stash")
                    .accessibilityLabel("Create stash")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                InlineErrorBanner(message: errorMessage)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            
            if !viewModel.isLoading && viewModel.errorMessage == nil && viewModel.stashes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No stashes")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Stash List
                List(viewModel.stashes) { stash in
                    StashRow(
                        stash: stash,
                        onApply: { Task { await viewModel.applyStash(index: stash.index) } },
                        onPopRequest: { pendingPopStash = stash },
                        onDropRequest: { pendingDropStash = stash }
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 300)
        .task {
            viewModel.setup(gitService: gitService, containerName: containerName)
            await viewModel.loadStashes()
        }
        .alert("Stash Changes", isPresented: $showingStashAlert) {
            TextField("Message (optional)", text: $stashMessage)
            Button("Cancel", role: .cancel) { }
            Button("Stash") {
                Task { await viewModel.createStash(message: stashMessage.isEmpty ? nil : stashMessage) }
                stashMessage = ""
            }
        }
        .alert("Drop Stash?", isPresented: Binding(
            get: { pendingDropStash != nil },
            set: { shouldShow in
                if !shouldShow {
                    pendingDropStash = nil
                }
            }
        )) {
            Button("Cancel", role: .cancel) {
                pendingDropStash = nil
            }
            Button("Drop", role: .destructive) {
                guard let stash = pendingDropStash else { return }
                Task { await viewModel.dropStash(index: stash.index) }
                pendingDropStash = nil
            }
        } message: {
            Text("This action removes the stash entry permanently.")
        }
        .alert("Pop Stash?", isPresented: Binding(
            get: { pendingPopStash != nil },
            set: { shouldShow in
                if !shouldShow {
                    pendingPopStash = nil
                }
            }
        )) {
            Button("Cancel", role: .cancel) {
                pendingPopStash = nil
            }
            Button("Pop", role: .destructive) {
                guard let stash = pendingPopStash else { return }
                Task { await viewModel.popStash(index: stash.index) }
                pendingPopStash = nil
            }
        } message: {
            Text("This applies changes and removes the stash entry.")
        }
    }
}

struct StashRow: View {
    let stash: GitStash
    let onApply: () -> Void
    let onPopRequest: () -> Void
    let onDropRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 28, height: 28)
                Text("\(stash.index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stash.message)
                    .font(.system(.body))
                    .lineLimit(1)
                Text(stash.hash.prefix(7))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()

            Menu {
                Button("Apply", action: onApply)
                Button("Pop", role: .destructive, action: onPopRequest)
                Divider()
                Button("Drop", role: .destructive, action: onDropRequest)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Stash actions")
            .accessibilityLabel("Stash actions")
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class GitStashViewModel: ObservableObject {
    @Published var stashes: [GitStash] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var gitService: GitService?
    private var containerName: String?
    
    func setup(gitService: GitService, containerName: String) {
        self.gitService = gitService
        self.containerName = containerName
    }
    
    func loadStashes() async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            stashes = try gitService.stashList(in: containerName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createStash(message: String?) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.stash(message: message, in: containerName)
            await loadStashes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func applyStash(index: Int) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.stashApply(index: index, in: containerName)
            await loadStashes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func popStash(index: Int) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.stashPop(index: index, in: containerName)
            await loadStashes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func dropStash(index: Int) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.stashDrop(index: index, in: containerName)
            await loadStashes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    GitStashView(
        gitService: GitService(runner: DockerService()),
        containerName: "preview"
    )
        .frame(width: 350, height: 400)
}
