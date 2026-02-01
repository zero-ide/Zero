import SwiftUI

struct GitPanelView: View {
    @StateObject private var gitService = GitPanelService()
    @State private var commitMessage = ""
    @State private var selectedFiles: Set<String> = []
    @State private var showingNewBranchAlert = false
    @State private var newBranchName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Branch Selector
            branchSection
            
            Divider()
            
            // Changes List
            changesSection
            
            Divider()
            
            // Commit Section
            commitSection
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await gitService.refresh()
        }
    }
    
    // MARK: - Branch Section
    
    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "branch")
                    .foregroundColor(.secondary)
                Text("Branch")
                    .font(.headline)
                Spacer()
                Button(action: { showingNewBranchAlert = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            
            Menu {
                ForEach(gitService.branches) { branch in
                    Button(action: {
                        Task { await gitService.checkout(branch: branch.name) }
                    }) {
                        HStack {
                            Text(branch.name)
                            if branch.isCurrent {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(gitService.currentBranch)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            if gitService.status.ahead > 0 || gitService.status.behind > 0 {
                HStack(spacing: 16) {
                    if gitService.status.ahead > 0 {
                        Label("\(gitService.status.ahead) ahead", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if gitService.status.behind > 0 {
                        Label("\(gitService.status.behind) behind", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .alert("New Branch", isPresented: $showingNewBranchAlert) {
            TextField("Branch name", text: $newBranchName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                Task {
                    await gitService.createBranch(name: newBranchName)
                    newBranchName = ""
                }
            }
        }
    }
    
    // MARK: - Changes Section
    
    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text("Changes")
                    .font(.headline)
                Spacer()
                if !selectedFiles.isEmpty {
                    Button("Stage \(selectedFiles.count)") {
                        Task { await gitService.stage(files: Array(selectedFiles)) }
                        selectedFiles.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    // Staged Changes
                    if !gitService.status.staged.isEmpty {
                        SectionHeader(title: "Staged", count: gitService.status.staged.count, color: .green)
                        ForEach(gitService.status.staged) { file in
                            FileRow(
                                path: file.path,
                                changeType: file.changeType,
                                isSelected: false
                            )
                        }
                    }
                    
                    // Unstaged Changes
                    if !gitService.status.unstaged.isEmpty {
                        SectionHeader(title: "Modified", count: gitService.status.unstaged.count, color: .orange)
                        ForEach(gitService.status.unstaged) { file in
                            FileRow(
                                path: file.path,
                                changeType: file.changeType,
                                isSelected: selectedFiles.contains(file.path)
                            )
                            .onTapGesture {
                                toggleSelection(file.path)
                            }
                        }
                    }
                    
                    // Untracked Files
                    if !gitService.status.untracked.isEmpty {
                        SectionHeader(title: "Untracked", count: gitService.status.untracked.count, color: .gray)
                        ForEach(gitService.status.untracked, id: \.self) { path in
                            FileRow(
                                path: path,
                                changeType: .added,
                                isSelected: selectedFiles.contains(path)
                            )
                            .onTapGesture {
                                toggleSelection(path)
                            }
                        }
                    }
                    
                    if gitService.status.staged.isEmpty && 
                       gitService.status.unstaged.isEmpty && 
                       gitService.status.untracked.isEmpty {
                        EmptyStateView()
                    }
                }
            }
        }
        .padding()
    }
    
    private func toggleSelection(_ path: String) {
        if selectedFiles.contains(path) {
            selectedFiles.remove(path)
        } else {
            selectedFiles.insert(path)
        }
    }
    
    // MARK: - Commit Section
    
    private var commitSection: some View {
        VStack(spacing: 12) {
            TextEditor(text: $commitMessage)
                .font(.system(.body, design: .monospaced))
                .frame(height: 60)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if commitMessage.isEmpty {
                            Text("Commit message...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                                .padding(.top, 12)
                        }
                    },
                    alignment: .topLeading
                )
            
            HStack(spacing: 12) {
                Button("Commit") {
                    Task { await commit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(commitMessage.isEmpty || gitService.status.staged.isEmpty)
                
                Button("Commit All") {
                    Task { await commitAll() }
                }
                .buttonStyle(.bordered)
                .disabled(commitMessage.isEmpty)
                
                Spacer()
                
                Button {
                    Task { await gitService.pull() }
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                
                Button {
                    Task { await gitService.push() }
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
    }
    
    private func commit() async {
        await gitService.commit(message: commitMessage)
        commitMessage = ""
    }
    
    private func commitAll() async {
        await gitService.commitAll(message: commitMessage)
        commitMessage = ""
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

struct FileRow: View {
    let path: String
    let changeType: GitFileChange.ChangeType
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
                .imageScale(.small)
            
            // Change type badge
            Text(changeTypeIcon)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(changeTypeColor)
                .frame(width: 20)
            
            // File path
            Text(path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    private var changeTypeIcon: String {
        switch changeType {
        case .added: return "A"
        case .modified: return "M"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        }
    }
    
    private var changeTypeColor: Color {
        switch changeType {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .purple
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No changes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }
}

#Preview {
    GitPanelView()
        .frame(width: 300, height: 600)
}
