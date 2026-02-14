import Foundation

/// 컨테이너 내부 파일 시스템 관리
class FileService {
    private let docker: DockerServiceProtocol
    private let containerName: String
    private let workspacePath: String
    
    init(
        containerName: String,
        workspacePath: String = "/workspace",
        docker: DockerServiceProtocol = DockerService()
    ) {
        self.docker = docker
        self.containerName = containerName
        self.workspacePath = (workspacePath as NSString).standardizingPath
    }
    
    /// 디렉토리 내용 조회 및 FileItem 변환
    func listDirectory(path: String? = nil) async throws -> [FileItem] {
        let targetPath = path ?? workspacePath
        
        // ls -la 실행
        let output = try docker.listFiles(container: containerName, path: targetPath)
        
        return parseLsOutput(output, basePath: targetPath)
    }
    
    /// ls -la 출력 파싱
    private func parseLsOutput(_ output: String, basePath: String) -> [FileItem] {
        var items: [FileItem] = []
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            // 빈 줄이나 total 줄 스킵
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("total") { continue }
            
            // ls -la 형식: drwxr-xr-x 2 root root 4096 Jan 29 12:00 dirname
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }
            
            let permissions = String(parts[0])
            let name = parts[8...].joined(separator: " ")
            
            // . 과 .. 스킵
            if name == "." || name == ".." { continue }
            
            let isDirectory = permissions.hasPrefix("d")
            let path = basePath == "/" ? "/\(name)" : "\(basePath)/\(name)"
            
            items.append(FileItem(
                name: name,
                path: path,
                isDirectory: isDirectory,
                children: isDirectory ? [] : nil
            ))
        }
        
        // 폴더 먼저, 그다음 파일 (알파벳 순)
        return items.sorted { item1, item2 in
            if item1.isDirectory != item2.isDirectory {
                return item1.isDirectory
            }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
    }
    
    /// 파일 내용 읽기
    func readFile(path: String) async throws -> String {
        let safePath = try resolveWorkspacePath(path)
        return try docker.readFile(container: containerName, path: safePath)
    }
    
    /// 파일 저장
    func writeFile(path: String, content: String) async throws {
        let safePath = try resolveWorkspacePath(path)
        try docker.writeFile(container: containerName, path: safePath, content: content)
    }

    func createDirectory(path: String) async throws {
        let safePath = try resolveWorkspacePath(path)
        try docker.ensureDirectory(container: containerName, path: safePath)
    }

    func createFile(path: String, initialContent: String = "") async throws {
        let safePath = try resolveWorkspacePath(path)
        try docker.writeFile(container: containerName, path: safePath, content: initialContent)
    }

    func renameItem(at path: String, to newPath: String) async throws {
        let safeSourcePath = try resolveWorkspacePath(path)
        let safeTargetPath = try resolveWorkspacePath(newPath)
        try docker.rename(container: containerName, from: safeSourcePath, to: safeTargetPath)
    }

    func deleteItem(at path: String, recursive: Bool = false) async throws {
        let safePath = try resolveWorkspacePath(path)
        try docker.remove(container: containerName, path: safePath, recursive: recursive)
    }

    private func resolveWorkspacePath(_ path: String) throws -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ZeroError.fileWriteFailed(path: path)
        }

        let candidatePath: String
        if trimmedPath.hasPrefix("/") {
            candidatePath = (trimmedPath as NSString).standardizingPath
        } else {
            candidatePath = ((workspacePath as NSString).appendingPathComponent(trimmedPath) as NSString).standardizingPath
        }

        let workspaceRoot = workspacePath
        let isInWorkspace = candidatePath == workspaceRoot || candidatePath.hasPrefix(workspaceRoot + "/")
        guard isInWorkspace else {
            throw ZeroError.fileWriteFailed(path: path)
        }

        return candidatePath
    }
}
