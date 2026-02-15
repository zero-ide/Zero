import XCTest
@testable import Zero

final class FileServiceTests: XCTestCase {
    func testCreateFileWritesAtWorkspaceAbsolutePath() async throws {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        try await service.createFile(path: "src/main.swift", initialContent: "print(\"hi\")")

        // Then
        XCTAssertEqual(docker.writtenFiles.count, 1)
        XCTAssertEqual(docker.writtenFiles.first?.path, "/workspace/src/main.swift")
        XCTAssertEqual(docker.writtenFiles.first?.content, "print(\"hi\")")
    }

    func testListDirectoryRejectsPathOutsideWorkspace() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            _ = try await service.listDirectory(path: "../outside")
            XCTFail("Expected listDirectory to reject traversal path")
        } catch {
            // Then
            XCTAssertTrue(docker.listCalls.isEmpty)
        }
    }

    func testReadFileOutsideWorkspaceThrowsReadErrorType() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            _ = try await service.readFile(path: "../secret")
            XCTFail("Expected readFile to reject traversal path")
        } catch let error as ZeroError {
            // Then
            XCTAssertEqual(error, .fileReadFailed(path: "../secret"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCreateDirectoryRejectsPathOutsideWorkspace() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            try await service.createDirectory(path: "../etc")
            XCTFail("Expected createDirectory to reject path traversal")
        } catch {
            // Then
            XCTAssertTrue(docker.ensuredDirectories.isEmpty)
            XCTAssertTrue(docker.writtenFiles.isEmpty)
        }
    }

    func testCreateDirectoryCallsDockerEnsureDirectoryWithWorkspaceAbsolutePath() async throws {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        try await service.createDirectory(path: "src/features")

        // Then
        XCTAssertEqual(docker.ensuredDirectories.count, 1)
        XCTAssertEqual(docker.ensuredDirectories.first, "/workspace/src/features")
    }

    func testCreateFileRejectsPathOutsideWorkspace() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            try await service.createFile(path: "../etc/passwd", initialContent: "")
            XCTFail("Expected createFile to reject traversal path")
        } catch {
            // Then
            XCTAssertTrue(docker.writtenFiles.isEmpty)
        }

        do {
            try await service.createFile(path: "/etc/passwd", initialContent: "")
            XCTFail("Expected createFile to reject absolute outside workspace path")
        } catch {
            // Then
            XCTAssertTrue(docker.writtenFiles.isEmpty)
        }
    }

    func testRenameItemCallsDockerRenameWithWorkspaceAbsolutePaths() async throws {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        try await service.renameItem(at: "src/old.swift", to: "src/new.swift")

        // Then
        XCTAssertEqual(docker.renameCalls.count, 1)
        XCTAssertEqual(docker.renameCalls.first?.from, "/workspace/src/old.swift")
        XCTAssertEqual(docker.renameCalls.first?.to, "/workspace/src/new.swift")
    }

    func testRenameItemRejectsDestinationOutsideWorkspace() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            try await service.renameItem(at: "src/old.swift", to: "../new.swift")
            XCTFail("Expected renameItem to reject destination path traversal")
        } catch {
            // Then
            XCTAssertTrue(docker.renameCalls.isEmpty)
        }
    }

    func testRenameItemRejectsSourceOutsideWorkspace() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            try await service.renameItem(at: "../old.swift", to: "src/new.swift")
            XCTFail("Expected renameItem to reject source path traversal")
        } catch {
            // Then
            XCTAssertTrue(docker.renameCalls.isEmpty)
        }
    }

    func testDeleteItemUsesRecursiveFlag() async throws {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        try await service.deleteItem(at: "build", recursive: true)

        // Then
        XCTAssertEqual(docker.removeCalls.count, 1)
        XCTAssertEqual(docker.removeCalls.first?.path, "/workspace/build")
        XCTAssertEqual(docker.removeCalls.first?.recursive, true)
    }

    func testDeleteItemUsesNonRecursiveFlag() async throws {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        try await service.deleteItem(at: "tmp.txt", recursive: false)

        // Then
        XCTAssertEqual(docker.removeCalls.count, 1)
        XCTAssertEqual(docker.removeCalls.first?.path, "/workspace/tmp.txt")
        XCTAssertEqual(docker.removeCalls.first?.recursive, false)
    }

    func testDeleteItemRejectsPathOutsideWorkspace() async {
        // Given
        let docker = MockFileOpsDockerService()
        let service = FileService(containerName: "zero-dev", workspacePath: "/workspace", docker: docker)

        // When
        do {
            try await service.deleteItem(at: "../../tmp/outside", recursive: true)
            XCTFail("Expected deleteItem to reject path traversal")
        } catch {
            // Then
            XCTAssertTrue(docker.removeCalls.isEmpty)
        }
    }
}

private final class MockFileOpsDockerService: DockerServiceProtocol {
    var executedScripts: [String] = []
    var listCalls: [String] = []
    var renameCalls: [(from: String, to: String)] = []
    var removeCalls: [(path: String, recursive: Bool)] = []
    var ensuredDirectories: [String] = []
    var writtenFiles: [(path: String, content: String)] = []

    func checkInstallation() throws -> Bool { true }
    func runContainer(image: String, name: String) throws -> String { "" }
    func executeCommand(container: String, command: String) throws -> String { "" }

    func executeShell(container: String, script: String) throws -> String {
        executedScripts.append(script)
        return ""
    }

    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String {
        executedScripts.append(script)
        return ""
    }

    func listFiles(container: String, path: String) throws -> String {
        listCalls.append(path)
        return ""
    }
    func readFile(container: String, path: String) throws -> String { "" }
    func writeFile(container: String, path: String, content: String) throws {
        writtenFiles.append((path: path, content: content))
    }

    func ensureDirectory(container: String, path: String) throws {
        ensuredDirectories.append(path)
    }

    func rename(container: String, from: String, to: String) throws {
        renameCalls.append((from: from, to: to))
    }

    func remove(container: String, path: String, recursive: Bool) throws {
        removeCalls.append((path: path, recursive: recursive))
    }

    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
    func fileExists(container: String, path: String) throws -> Bool { true }
    func cancelCurrentExecution() {}
}
