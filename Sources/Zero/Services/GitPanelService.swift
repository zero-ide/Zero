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
            errorMessage = error.localizedDescription
        }
    }
    
    func pull() async {
        guard let gitService = gitService, let containerName = containerName else { return }
        
        do {
            try gitService.pull(in: containerName)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
