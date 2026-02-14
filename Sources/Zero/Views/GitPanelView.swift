import SwiftUI

struct GitPanelView: View {
    @StateObject private var panelService = GitPanelService()

    let gitService: GitService
    let containerName: String

    @State private var commitMessage = ""
    @State private var selectedFiles: Set<String> = []
    @State private var previewedPath: String?
    @State private var showingNewBranchAlert = false
    @State private var newBranchName = ""

    var body: some View {
        VStack(spacing: 0) {
            branchSection

            Divider()

            changesSection

            Divider()

            commitSection

            if let errorMessage = panelService.errorMessage, !errorMessage.isEmpty {
                Divider()
                InlineErrorBanner(message: errorMessage)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            panelService.setup(gitService: gitService, containerName: containerName)
            await panelService.refresh()
        }
    }

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "branch")
                    .foregroundColor(.secondary)
                Text("Branch")
                    .font(.headline)
                Spacer()

                Button {
                    Task { await panelService.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh status")
                .accessibilityLabel("Refresh git status")

                Button {
                    showingNewBranchAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create branch")
                .accessibilityLabel("Create new branch")
            }

            Menu {
                ForEach(panelService.branches) { branch in
                    Button {
                        Task { await panelService.checkout(branch: branch.name) }
                    } label: {
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
                    Text(panelService.currentBranch)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            if panelService.status.ahead > 0 || panelService.status.behind > 0 {
                HStack(spacing: 16) {
                    if panelService.status.ahead > 0 {
                        Label("\(panelService.status.ahead) ahead", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if panelService.status.behind > 0 {
                        Label("\(panelService.status.behind) behind", systemImage: "arrow.down")
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
                let branchName = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !branchName.isEmpty else { return }

                Task {
                    await panelService.createBranch(name: branchName)
                    newBranchName = ""
                }
            }
        }
    }

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
                        let files = Array(selectedFiles)
                        Task { await panelService.stage(files: files) }
                        selectedFiles.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    if !panelService.status.staged.isEmpty {
                        SectionHeader(title: "Staged", count: panelService.status.staged.count, color: .green)
                        ForEach(panelService.status.staged) { file in
                            FileRow(
                                path: file.path,
                                changeType: file.changeType,
                                isSelected: false,
                                isPreviewed: previewedPath == file.path,
                                showSelectionIndicator: false
                            )
                            .onTapGesture {
                                previewedPath = file.path
                                Task { await panelService.loadDiff(for: file.path, staged: true) }
                            }
                        }
                    }

                    if !panelService.status.unstaged.isEmpty {
                        SectionHeader(title: "Modified", count: panelService.status.unstaged.count, color: .orange)
                        ForEach(panelService.status.unstaged) { file in
                            FileRow(
                                path: file.path,
                                changeType: file.changeType,
                                isSelected: selectedFiles.contains(file.path),
                                isPreviewed: previewedPath == file.path,
                                showSelectionIndicator: true
                            )
                            .onTapGesture {
                                toggleSelection(file.path)
                                previewedPath = file.path
                                Task { await panelService.loadDiff(for: file.path, staged: false) }
                            }
                        }
                    }

                    if !panelService.status.untracked.isEmpty {
                        SectionHeader(title: "Untracked", count: panelService.status.untracked.count, color: .gray)
                        ForEach(panelService.status.untracked, id: \.self) { path in
                            FileRow(
                                path: path,
                                changeType: .added,
                                isSelected: selectedFiles.contains(path),
                                isPreviewed: previewedPath == path,
                                showSelectionIndicator: true
                            )
                            .onTapGesture {
                                toggleSelection(path)
                                previewedPath = path
                                panelService.showUntrackedDiffPlaceholder(for: path)
                            }
                        }
                    }

                    if panelService.status.staged.isEmpty &&
                        panelService.status.unstaged.isEmpty &&
                        panelService.status.untracked.isEmpty {
                        EmptyStateView()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(panelService.selectedDiffTitle ?? "Diff Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView([.vertical, .horizontal]) {
                    Text(panelService.selectedDiff.isEmpty ? "Select a changed file to preview diff." : panelService.selectedDiff)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(minHeight: 120, maxHeight: 180)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
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

    private var commitSection: some View {
        VStack(spacing: 12) {
            TextEditor(text: $commitMessage)
                .font(.system(.body, design: .monospaced))
                .frame(height: 60)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
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
                .disabled(commitMessage.isEmpty || panelService.status.staged.isEmpty)

                Button("Commit All") {
                    Task { await commitAll() }
                }
                .buttonStyle(.bordered)
                .disabled(commitMessage.isEmpty)

                Spacer()

                Button {
                    Task { await panelService.pull() }
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Pull from remote")
                .accessibilityLabel("Pull from remote")

                Button {
                    Task { await panelService.push() }
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
                .help("Push to remote")
                .accessibilityLabel("Push to remote")
            }
        }
        .padding()
    }

    private func commit() async {
        await panelService.commit(message: commitMessage)
        commitMessage = ""
    }

    private func commitAll() async {
        await panelService.commitAll(message: commitMessage)
        commitMessage = ""
    }
}

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
    let isPreviewed: Bool
    let showSelectionIndicator: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showSelectionIndicator {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .imageScale(.small)
            } else {
                Image(systemName: isPreviewed ? "eye.fill" : "eye")
                    .foregroundColor(isPreviewed ? .accentColor : .secondary)
                    .imageScale(.small)
            }

            Text(changeTypeIcon)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(changeTypeColor)
                .frame(width: 20)

            Text(path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if isPreviewed {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background((isSelected || isPreviewed) ? Color.accentColor.opacity(0.12) : Color.clear)
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
    GitPanelView(
        gitService: GitService(runner: DockerService()),
        containerName: "preview"
    )
    .frame(width: 300, height: 600)
}
