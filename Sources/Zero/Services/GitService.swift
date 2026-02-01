import Foundation

// MARK: - Git Models

struct GitStatus: Codable {
    let branch: String
    let ahead: Int
    let behind: Int
    let staged: [GitFileChange]
    let unstaged: [GitFileChange]
    let untracked: [String]
}

struct GitFileChange: Codable, Identifiable {
    let id = UUID()
    let path: String
    let changeType: ChangeType
    
    enum ChangeType: String, Codable {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"
        case copied = "C"
    }
}

struct GitCommit: Codable, Identifiable {
    let id: String
    let shortHash: String
    let message: String
    let author: String
    let date: String
    let filesChanged: Int
    let insertions: Int
    let deletions: Int
}

struct GitBranch: Codable, Identifiable {
    let id = UUID()
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
    let commitHash: String?
    let commitMessage: String?
}

// MARK: - Git Service

struct GitService {
    let runner: ContainerRunning
    
    init(runner: ContainerRunning) {
        self.runner = runner
    }
    
    // MARK: - Clone
    
    func clone(repoURL: URL, token: String, to containerName: String) throws {
        guard var components = URLComponents(url: repoURL, resolvingAgainstBaseURL: false) else {
            throw ZeroError.invalidRepositoryURL
        }
        
        components.user = "x-access-token"
        components.password = token
        
        guard let authenticatedURL = components.string else {
            throw ZeroError.invalidRepositoryURL
        }
        
        let command = "mkdir -p /workspace && cd /workspace && git clone \(authenticatedURL) ."
        
        do {
            _ = try runner.executeShell(container: containerName, script: command)
        } catch {
            throw ZeroError.gitCloneFailed(reason: error.localizedDescription)
        }
    }
    
    // MARK: - Status
    
    func status(in containerName: String) throws -> GitStatus {
        let command = "cd /workspace && git status --porcelain -b"
        let output = try runner.executeShell(container: containerName, script: command)
        
        return try parseStatusOutput(output)
    }
    
    private func parseStatusOutput(_ output: String) throws -> GitStatus {
        var branch = "main"
        var ahead = 0
        var behind = 0
        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []
        var untracked: [String] = []
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("## ") {
                // Parse branch info
                let branchInfo = String(line.dropFirst(3))
                if let branchEnd = branchInfo.range(of: "...")?.lowerBound {
                    branch = String(branchInfo[..<branchEnd])
                } else if let spaceIndex = branchInfo.firstIndex(of: " ") {
                    branch = String(branchInfo[..<spaceIndex])
                } else {
                    branch = branchInfo
                }
                
                // Parse ahead/behind
                if branchInfo.contains("[ahead ") {
                    if let start = branchInfo.range(of: "[ahead ")?.upperBound,
                       let end = branchInfo[start...].firstIndex(of: "]") {
                        let aheadStr = String(branchInfo[start..<end])
                        ahead = Int(aheadStr) ?? 0
                    }
                }
                if branchInfo.contains("[behind ") {
                    if let start = branchInfo.range(of: "[behind ")?.upperBound,
                       let end = branchInfo[start...].firstIndex(of: "]") {
                        let behindStr = String(branchInfo[start..<end])
                        behind = Int(behindStr) ?? 0
                    }
                }
            } else if line.count >= 2 {
                let indexStatus = line.prefix(1)
                let workTreeStatus = line.dropFirst().prefix(1)
                let filePath = String(line.dropFirst(3))
                
                if indexStatus != " " && indexStatus != "?" {
                    // Staged changes
                    if let type = GitFileChange.ChangeType(rawValue: String(indexStatus)) {
                        staged.append(GitFileChange(path: filePath, changeType: type))
                    }
                } else if workTreeStatus != " " {
                    // Unstaged changes
                    if let type = GitFileChange.ChangeType(rawValue: String(workTreeStatus)) {
                        unstaged.append(GitFileChange(path: filePath, changeType: type))
                    }
                } else if indexStatus == "?" {
                    // Untracked
                    untracked.append(filePath)
                }
            }
        }
        
        return GitStatus(
            branch: branch,
            ahead: ahead,
            behind: behind,
            staged: staged,
            unstaged: unstaged,
            untracked: untracked
        )
    }
    
    // MARK: - Add
    
    func add(files: [String], in containerName: String) throws {
        let fileList = files.joined(separator: " ")
        let command = "cd /workspace && git add \(fileList)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func addAll(in containerName: String) throws {
        let command = "cd /workspace && git add ."
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Commit
    
    func commit(message: String, in containerName: String) throws {
        // Escape quotes in message
        let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let command = "cd /workspace && git commit -m \"\(escapedMessage)\""
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func commitAll(message: String, in containerName: String) throws {
        try addAll(in: containerName)
        try commit(message: message, in: containerName)
    }
    
    // MARK: - Log
    
    func log(maxCount: Int = 20, in containerName: String) throws -> [GitCommit] {
        let format = "%H|%h|%s|%an|%ar|%d"
        let command = "cd /workspace && git log -\(maxCount) --pretty=format:'\(format)'"
        let output = try runner.executeShell(container: containerName, script: command)
        
        return parseLogOutput(output)
    }
    
    private func parseLogOutput(_ output: String) -> [GitCommit] {
        var commits: [GitCommit] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 5 else { continue }
            
            let commit = GitCommit(
                id: parts[0],
                shortHash: parts[1],
                message: parts[2],
                author: parts[3],
                date: parts[4],
                filesChanged: 0,
                insertions: 0,
                deletions: 0
            )
            commits.append(commit)
        }
        
        return commits
    }
    
    // MARK: - Branch
    
    func branches(in containerName: String) throws -> [GitBranch] {
        let command = "cd /workspace && git branch -a -v --format='%(refname:short)|%(HEAD)|%(objectname:short)|%(contents:subject)'"
        let output = try runner.executeShell(container: containerName, script: command)
        
        return parseBranchOutput(output)
    }
    
    private func parseBranchOutput(_ output: String) -> [GitBranch] {
        var branches: [GitBranch] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }
            
            let name = parts[0]
            let isCurrent = parts[1] == "*"
            let isRemote = name.hasPrefix("origin/")
            let hash = parts[2]
            let message = parts.count > 3 ? parts[3] : nil
            
            // Skip duplicate remote branches for local branches
            if !isRemote && branches.contains(where: { $0.name == name }) {
                continue
            }
            
            branches.append(GitBranch(
                name: name,
                isCurrent: isCurrent,
                isRemote: isRemote,
                commitHash: hash,
                commitMessage: message
            ))
        }
        
        return branches
    }
    
    func createBranch(name: String, in containerName: String) throws {
        let command = "cd /workspace && git branch \(name)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func checkout(branch: String, in containerName: String) throws {
        let command = "cd /workspace && git checkout \(branch)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func createAndCheckoutBranch(name: String, in containerName: String) throws {
        let command = "cd /workspace && git checkout -b \(name)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func deleteBranch(name: String, force: Bool = false, in containerName: String) throws {
        let flag = force ? "-D" : "-d"
        let command = "cd /workspace && git branch \(flag) \(name)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Push/Pull
    
    func push(branch: String? = nil, in containerName: String) throws {
        let branchArg = branch ?? ""
        let command = "cd /workspace && git push origin \(branchArg)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func pull(in containerName: String) throws {
        let command = "cd /workspace && git pull"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Diff
    
    func diff(file: String? = nil, in containerName: String) throws -> String {
        let fileArg = file ?? ""
        let command = "cd /workspace && git diff \(fileArg)"
        return try runner.executeShell(container: containerName, script: command)
    }
    
    func diffStaged(in containerName: String) throws -> String {
        let command = "cd /workspace && git diff --staged"
        return try runner.executeShell(container: containerName, script: command)
    }
}
