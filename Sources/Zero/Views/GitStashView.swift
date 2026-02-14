import SwiftUI

struct GitStashView: View {
    @StateObject private var viewModel = GitStashViewModel()
    @State private var stashMessage = ""
    @State private var showingStashAlert = false

    let gitService: GitService
    let containerName: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "archivebox")
                    .foregroundColor(.secondary)
                Text("Stash")
                    .font(.headline)
                Spacer()
                Button {
                    showingStashAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            Divider()
            
            // Stash List
            List(viewModel.stashes) { stash in
                StashRow(stash: stash)
                    .contextMenu {
                        Button("Apply") {
                            Task { await viewModel.applyStash(index: stash.index) }
                        }
                        Button("Pop") {
                            Task { await viewModel.popStash(index: stash.index) }
                        }
                        Divider()
                        Button("Drop", role: .destructive) {
                            Task { await viewModel.dropStash(index: stash.index) }
                        }
                    }
            }
            .listStyle(.plain)
            
            if viewModel.stashes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No stashes")
                        .foregroundColor(.secondary)
                }
                Spacer()
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
    }
}

struct StashRow: View {
    let stash: GitStash
    
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
