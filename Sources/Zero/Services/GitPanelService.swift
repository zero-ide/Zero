import Foundation
import Combine

@MainActor
class GitPanelService: ObservableObject {
    @Published var status: GitStatus = GitStatus(
        branch: "main",
        ahead: 0,
        behind: 0,
        staged: [],
        unstaged: [],
        untracked: []
    )
    @Published var branches: [GitBranch] = []
    @Published var currentBranch = "main"
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var selectedDiff: String = ""
    @Published var selectedDiffTitle: String?
    
    private var gitService: GitService?
    private var containerName: String?
    
    func setup(gitService: GitService, containerName: String) {
        self.gitService = gitService
        self.containerName = containerName
    }
    
    func refresh() async {
        guard let gitService = gitService, let containerName = containerName else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            status = try gitService.status(in: containerName)
            currentBranch = status.branch
            branches = try gitService.branches(in: containerName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stage(files: [String]) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.add(files: files, in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stageAll() async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.addAll(in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func commit(message: String) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.commit(message: message, in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func commitAll(message: String) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.commitAll(message: message, in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createBranch(name: String) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.createAndCheckoutBranch(name: name, in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func checkout(branch: String) async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.checkout(branch: branch, in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func push() async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.push(in: containerName)
            await refresh()
        } catch {
            errorMessage = mapRemoteActionError(error, action: .push)
        }
    }
    
    func pull() async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.pull(in: containerName)
            await refresh()
        } catch {
            errorMessage = mapRemoteActionError(error, action: .pull)
        }
    }

    func loadDiff(for path: String, staged: Bool) async {
        guard let gitService = gitService, let containerName = containerName else { return }

        do {
            let diff: String
            if staged {
                diff = try gitService.diffStaged(file: path, in: containerName)
            } else {
                diff = try gitService.diff(file: path, in: containerName)
            }

            selectedDiffTitle = (staged ? "Staged" : "Working Tree") + " · \(path)"
            selectedDiff = diff.isEmpty ? "No diff output for this file." : diff
            errorMessage = nil
        } catch {
            selectedDiffTitle = "Diff · \(path)"
            selectedDiff = "Failed to load diff: \(error.localizedDescription)"
            errorMessage = error.localizedDescription
        }
    }

    func showUntrackedDiffPlaceholder(for path: String) {
        selectedDiffTitle = "Untracked · \(path)"
        selectedDiff = "Untracked files have no git diff until staged."
    }

    private enum RemoteAction {
        case pull
        case push
    }

    private func mapRemoteActionError(_ error: Error, action: RemoteAction) -> String {
        let message = error.localizedDescription
        let normalized = message.lowercased()

        if action == .push && containsAny(normalized, patterns: ["non-fast-forward", "failed to push some refs", "[rejected]", "fetch first"]) {
            return "Push rejected because remote has new commits. Pull, resolve conflicts if needed, then push again."
        }

        if action == .pull && containsAny(normalized, patterns: ["automatic merge failed", "merge conflict", "conflict"]) {
            return "Pull hit merge conflicts. Resolve conflicted files, commit, then pull again."
        }

        if containsAny(normalized, patterns: ["authentication failed", "permission denied", "could not read from remote repository", "repository not found"]) {
            return "Git authentication or permission failed. Verify credentials and repository access, then retry."
        }

        return message
    }

    private func containsAny(_ text: String, patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }
}
