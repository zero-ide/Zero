import Foundation

/// 컨테이너 내부 파일 시스템 관리
class FileService {
    private let docker: DockerService
    private let containerName: String
    private let workspacePath: String
    
    init(containerName: String, workspacePath: String = "/workspace") {
        self.docker = DockerService()
        self.containerName = containerName
        self.workspacePath = workspacePath
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
        return try docker.readFile(container: containerName, path: path)
    }
    
    /// 파일 저장
    func writeFile(path: String, content: String) async throws {
        try docker.writeFile(container: containerName, path: path, content: content)
    }
}
