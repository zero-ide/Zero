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

struct GitStash: Codable, Identifiable {
    let id = UUID()
    let index: Int
    let hash: String
    let message: String
}

// MARK: - Git Service

struct GitService {
    let runner: ContainerRunning
    
    init(runner: ContainerRunning) {
        self.runner = runner
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func firstMatchInt(in text: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return 0 }
        let capture = match.range(at: 1)
        guard let captureRange = Range(capture, in: text) else { return 0 }
        return Int(text[captureRange]) ?? 0
    }

    private func decodePorcelainPathComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") else {
            return trimmed
        }

        let inner = String(trimmed.dropFirst().dropLast())
        var decodedBytes: [UInt8] = []
        var index = inner.startIndex

        while index < inner.endIndex {
            let character = inner[index]

            if character != "\\" {
                decodedBytes.append(contentsOf: String(character).utf8)
                index = inner.index(after: index)
                continue
            }

            let escapeIndex = inner.index(after: index)
            guard escapeIndex < inner.endIndex else {
                decodedBytes.append(UInt8(ascii: "\\"))
                break
            }

            let escape = inner[escapeIndex]

            if ("0"..."7").contains(escape) {
                var octalDigits = String(escape)
                var digitIndex = inner.index(after: escapeIndex)

                while digitIndex < inner.endIndex && octalDigits.count < 3 {
                    let next = inner[digitIndex]
                    guard ("0"..."7").contains(next) else { break }
                    octalDigits.append(next)
                    digitIndex = inner.index(after: digitIndex)
                }

                if let byte = UInt8(octalDigits, radix: 8) {
                    decodedBytes.append(byte)
                }

                index = digitIndex
                continue
            }

            switch escape {
            case "\\": decodedBytes.append(UInt8(ascii: "\\"))
            case "\"": decodedBytes.append(UInt8(ascii: "\""))
            case "n": decodedBytes.append(UInt8(ascii: "\n"))
            case "r": decodedBytes.append(UInt8(ascii: "\r"))
            case "t": decodedBytes.append(UInt8(ascii: "\t"))
            default:
                decodedBytes.append(UInt8(ascii: "\\"))
                decodedBytes.append(contentsOf: String(escape).utf8)
            }
            index = inner.index(after: escapeIndex)
        }

        return String(bytes: decodedBytes, encoding: .utf8) ?? String(decoding: decodedBytes, as: UTF8.self)
    }

    private func splitRenameComponents(_ value: String) -> (String, String)? {
        var index = value.startIndex
        var inQuotes = false
        var isEscaped = false

        while index < value.endIndex {
            let character = value[index]

            if isEscaped {
                isEscaped = false
                index = value.index(after: index)
                continue
            }

            if character == "\\" {
                isEscaped = true
                index = value.index(after: index)
                continue
            }

            if character == "\"" {
                inQuotes.toggle()
                index = value.index(after: index)
                continue
            }

            if !inQuotes, value[index...].hasPrefix(" -> ") {
                let left = String(value[..<index])
                let rightStart = value.index(index, offsetBy: 4)
                let right = String(value[rightStart...])
                return (left, right)
            }

            index = value.index(after: index)
        }

        return nil
    }

    private func normalizePorcelainPath(_ rawPath: String, isRenameOrCopy: Bool) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespaces)
        guard isRenameOrCopy else {
            return decodePorcelainPathComponent(trimmed)
        }

        let destination = splitRenameComponents(trimmed)?.1 ?? trimmed
        return decodePorcelainPathComponent(destination)
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
        
        let command = "mkdir -p /workspace && cd /workspace && git clone \(shellQuote(authenticatedURL)) ."
        
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
                let branchSection = branchInfo.components(separatedBy: " [").first ?? branchInfo
                if let branchEnd = branchSection.range(of: "...")?.lowerBound {
                    branch = String(branchSection[..<branchEnd])
                } else {
                    branch = branchSection
                }

                ahead = firstMatchInt(in: branchInfo, pattern: "ahead\\s+(\\d+)")
                behind = firstMatchInt(in: branchInfo, pattern: "behind\\s+(\\d+)")
            } else if line.count >= 2 {
                let indexStatus = line.prefix(1)
                let workTreeStatus = line.dropFirst().prefix(1)
                let isRenameOrCopy = indexStatus == "R" || indexStatus == "C" || workTreeStatus == "R" || workTreeStatus == "C"
                let filePath = normalizePorcelainPath(String(line.dropFirst(3)), isRenameOrCopy: isRenameOrCopy)

                if indexStatus == "?" && workTreeStatus == "?" {
                    // Untracked
                    untracked.append(filePath)
                } else {
                    if indexStatus != " ", let type = GitFileChange.ChangeType(rawValue: String(indexStatus)) {
                        staged.append(GitFileChange(path: filePath, changeType: type))
                    }

                    if workTreeStatus != " ", let type = GitFileChange.ChangeType(rawValue: String(workTreeStatus)) {
                        unstaged.append(GitFileChange(path: filePath, changeType: type))
                    }
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
        guard !files.isEmpty else { return }
        let fileList = files.map(shellQuote).joined(separator: " ")
        let command = "cd /workspace && git add -- \(fileList)"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func addAll(in containerName: String) throws {
        let command = "cd /workspace && git add ."
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Commit
    
    func commit(message: String, in containerName: String) throws {
        let command = "cd /workspace && git commit -m \(shellQuote(message))"
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
        let command = "cd /workspace && git branch \(shellQuote(name))"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func checkout(branch: String, in containerName: String) throws {
        let command = "cd /workspace && git checkout \(shellQuote(branch))"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func createAndCheckoutBranch(name: String, in containerName: String) throws {
        let command = "cd /workspace && git checkout -b \(shellQuote(name))"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func deleteBranch(name: String, force: Bool = false, in containerName: String) throws {
        let flag = force ? "-D" : "-d"
        let command = "cd /workspace && git branch \(flag) \(shellQuote(name))"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Push/Pull
    
    func push(branch: String? = nil, in containerName: String) throws {
        let branchArg = branch.map { shellQuote($0) } ?? ""
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
        let command = fileArg.isEmpty
            ? "cd /workspace && git diff"
            : "cd /workspace && git diff -- \(shellQuote(fileArg))"
        return try runner.executeShell(container: containerName, script: command)
    }
    
    func diffStaged(file: String? = nil, in containerName: String) throws -> String {
        let fileArg = file ?? ""
        let command = fileArg.isEmpty
            ? "cd /workspace && git diff --staged"
            : "cd /workspace && git diff --staged -- \(shellQuote(fileArg))"
        return try runner.executeShell(container: containerName, script: command)
    }

    func show(commit hash: String, in containerName: String) throws -> String {
        let command = "cd /workspace && git show --stat --patch --pretty=format:'%h %s%nAuthor: %an%nDate: %ar%n' \(shellQuote(hash))"
        return try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Stash
    
    func stash(message: String? = nil, in containerName: String) throws {
        let command: String
        if let message = message {
            command = "cd /workspace && git stash push -m \(shellQuote(message))"
        } else {
            command = "cd /workspace && git stash push"
        }
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func stashList(in containerName: String) throws -> [GitStash] {
        let command = "cd /workspace && git stash list --format='%H|%s'"
        let output = try runner.executeShell(container: containerName, script: command)
        
        var stashes: [GitStash] = []
        let lines = output.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { continue }
            
            stashes.append(GitStash(
                index: index,
                hash: parts[0],
                message: parts[1]
            ))
        }
        
        return stashes
    }
    
    func stashPop(index: Int = 0, in containerName: String) throws {
        let command = "cd /workspace && git stash pop stash@{\(index)}"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func stashApply(index: Int = 0, in containerName: String) throws {
        let command = "cd /workspace && git stash apply stash@{\(index)}"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func stashDrop(index: Int, in containerName: String) throws {
        let command = "cd /workspace && git stash drop stash@{\(index)}"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Merge
    
    func merge(branch: String, in containerName: String) throws {
        let command = "cd /workspace && git merge \(shellQuote(branch))"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func mergeAbort(in containerName: String) throws {
        let command = "cd /workspace && git merge --abort"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Rebase
    
    func rebase(branch: String, in containerName: String) throws {
        let command = "cd /workspace && git rebase \(shellQuote(branch))"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func rebaseAbort(in containerName: String) throws {
        let command = "cd /workspace && git rebase --abort"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    func rebaseContinue(in containerName: String) throws {
        let command = "cd /workspace && git rebase --continue"
        _ = try runner.executeShell(container: containerName, script: command)
    }
    
    // MARK: - Conflict Resolution
    
    func isMergeConflict(in containerName: String) throws -> Bool {
        let command = "cd /workspace && git diff --name-only --diff-filter=U"
        let output = try runner.executeShell(container: containerName, script: command)
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func conflictedFiles(in containerName: String) throws -> [String] {
        let command = "cd /workspace && git diff --name-only --diff-filter=U"
        let output = try runner.executeShell(container: containerName, script: command)
        
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
