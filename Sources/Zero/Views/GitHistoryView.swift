import SwiftUI

struct GitHistoryView: View {
    @StateObject private var viewModel = GitHistoryViewModel()
    @State private var selectedCommit: GitCommit?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.secondary)
                Text("History")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            
            Divider()
            
            // Commit List
            List(viewModel.commits) { commit in
                CommitRow(commit: commit)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCommit = commit
                    }
                    .background(selectedCommit?.id == commit.id ? Color.blue.opacity(0.1) : Color.clear)
            }
            .listStyle(.plain)
            
            if let commit = selectedCommit {
                Divider()
                CommitDetailView(commit: commit, diff: viewModel.diff)
                    .frame(height: 200)
            }
        }
        .frame(minWidth: 300)
        .task {
            await viewModel.loadHistory()
        }
    }
}

struct CommitRow: View {
    let commit: GitCommit
    
    var body: some View {
        HStack(spacing: 12) {
            // Commit icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .font(.system(.body))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(commit.shortHash)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(commit.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CommitDetailView: View {
    let commit: GitCommit
    let diff: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(commit.shortHash)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Text(commit.message)
                    .font(.caption)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Diff view
            ScrollView {
                if diff.isEmpty {
                    Text("No changes to display")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
            }
        }
    }
}

@MainActor
class GitHistoryViewModel: ObservableObject {
    @Published var commits: [GitCommit] = []
    @Published var diff: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var gitService: GitService?
    private var containerName: String?
    
    func setup(gitService: GitService, containerName: String) {
        self.gitService = gitService
        self.containerName = containerName
    }
    
    func loadHistory() async {
        guard let gitService = gitService, let containerName = containerName else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            commits = try gitService.log(maxCount: 50, in: containerName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadDiff(for commit: GitCommit) async {
        guard let gitService = gitService, let containerName = containerName else {
            return
        }
        
        do {
            diff = try gitService.diff(in: containerName)
        } catch {
            diff = "Failed to load diff: \(error.localizedDescription)"
        }
    }
}

#Preview {
    GitHistoryView()
        .frame(width: 400, height: 600)
}
