import XCTest
@testable import Zero

// Mock for DockerService (Dependency Injection)
class MockContainerRunner: ContainerRunning {
    var executedContainer: String?
    var executedCommand: String?
    var executedScript: String?
    var nextShellOutput: String = "Shell script executed"
    
    func executeCommand(container: String, command: String) throws -> String {
        self.executedContainer = container
        self.executedCommand = command
        return "Cloning into..."
    }
    
    func executeShell(container: String, script: String) throws -> String {
        self.executedContainer = container
        self.executedScript = script
        return nextShellOutput
    }

    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String {
        self.executedContainer = container
        self.executedScript = script
        onOutput(nextShellOutput)
        return nextShellOutput
    }
}

final class GitServiceTests: XCTestCase {
    func testCloneRepository() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)
        let repoURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        let token = "ghp_secret_token"
        let containerName = "zero-dev-container"
        
        // When
        try service.clone(repoURL: repoURL, token: token, to: containerName)
        
        // Then
        XCTAssertEqual(mockRunner.executedContainer, containerName)
        
        // 토큰이 포함된 URL이 명령어로 전달되었는지 확인
        let command = mockRunner.executedScript ?? ""
        XCTAssertTrue(command.contains("x-access-token:ghp_secret_token@github.com/zero-ide/Zero.git"))
        
        // /workspace 디렉토리에 clone되는지 확인
        XCTAssertTrue(command.contains("/workspace"), "Clone should target /workspace directory")
        XCTAssertTrue(command.contains("mkdir -p /workspace"), "Should create directory")
    }

    func testDiffForFileUsesPathSeparator() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)

        // When
        _ = try service.diff(file: "Sources/Zero/main.swift", in: "zero-dev-container")

        // Then
        XCTAssertEqual(mockRunner.executedScript, "cd /workspace && git diff -- 'Sources/Zero/main.swift'")
    }

    func testDiffStagedForFileUsesPathSeparator() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)

        // When
        _ = try service.diffStaged(file: "README.md", in: "zero-dev-container")

        // Then
        XCTAssertEqual(mockRunner.executedScript, "cd /workspace && git diff --staged -- 'README.md'")
    }

    func testShowCommitBuildsExpectedCommand() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)

        // When
        _ = try service.show(commit: "abc1234", in: "zero-dev-container")

        // Then
        XCTAssertEqual(
            mockRunner.executedScript,
            "cd /workspace && git show --stat --patch --pretty=format:'%h %s%nAuthor: %an%nDate: %ar%n' 'abc1234'"
        )
    }

    func testStatusParsesAheadBehindAndUntracked() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/lsp...origin/feature/lsp [ahead 2, behind 1]
        ?? docs/new file.md
         M Sources/Zero/Views/EditorView.swift
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.branch, "feature/lsp")
        XCTAssertEqual(status.ahead, 2)
        XCTAssertEqual(status.behind, 1)
        XCTAssertEqual(status.untracked, ["docs/new file.md"])
    }

    func testStatusParsesMixedStagedAndUnstagedForSamePath() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/mixed...origin/feature/mixed
        MM Sources/Zero/Views/EditorView.swift
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.staged.count, 1)
        XCTAssertEqual(status.unstaged.count, 1)
        XCTAssertEqual(status.staged.first?.path, "Sources/Zero/Views/EditorView.swift")
        XCTAssertEqual(status.unstaged.first?.path, "Sources/Zero/Views/EditorView.swift")
        XCTAssertEqual(status.staged.first?.changeType, .modified)
        XCTAssertEqual(status.unstaged.first?.changeType, .modified)
    }

    func testStatusParsesRenamePathAsDestinationOnly() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/rename...origin/feature/rename
        R  Sources/Zero/Old.swift -> Sources/Zero/New.swift
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.staged.count, 1)
        XCTAssertEqual(status.staged.first?.changeType, .renamed)
        XCTAssertEqual(status.staged.first?.path, "Sources/Zero/New.swift")
    }

    func testStatusParsesQuotedUntrackedPath() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/quoted...origin/feature/quoted
        ?? "docs/new file.md"
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.untracked, ["docs/new file.md"])
    }

    func testStatusDoesNotTreatArrowInPlainPathAsRename() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/arrow...origin/feature/arrow
        A  notes/a -> b.txt
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.staged.count, 1)
        XCTAssertEqual(status.staged.first?.changeType, .added)
        XCTAssertEqual(status.staged.first?.path, "notes/a -> b.txt")
    }

    func testStatusParsesQuotedRenameDestination() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/rename-quoted...origin/feature/rename-quoted
        R  "notes/old file.txt" -> "notes/new file.txt"
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.staged.count, 1)
        XCTAssertEqual(status.staged.first?.changeType, .renamed)
        XCTAssertEqual(status.staged.first?.path, "notes/new file.txt")
    }

    func testStatusParsesOctalEscapedQuotedPath() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/octal...origin/feature/octal
        ?? "docs/\\141\\040file.txt"
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.untracked, ["docs/a file.txt"])
    }

    func testStatusParsesRenameDestinationContainingArrow() throws {
        // Given
        let mockRunner = MockContainerRunner()
        mockRunner.nextShellOutput = """
        ## feature/rename-arrow...origin/feature/rename-arrow
        R  "notes/old.txt" -> "notes/new -> final.txt"
        """
        let service = GitService(runner: mockRunner)

        // When
        let status = try service.status(in: "zero-dev-container")

        // Then
        XCTAssertEqual(status.staged.count, 1)
        XCTAssertEqual(status.staged.first?.changeType, .renamed)
        XCTAssertEqual(status.staged.first?.path, "notes/new -> final.txt")
    }

    func testAddFilesQuotesPathsAndUsesSeparator() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)

        // When
        try service.add(files: ["file one.swift", "-strange.txt"], in: "zero-dev-container")

        // Then
        XCTAssertEqual(mockRunner.executedScript, "cd /workspace && git add -- 'file one.swift' '-strange.txt'")
    }

    func testCommitEscapesSingleQuoteSafely() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)

        // When
        try service.commit(message: "feat: it's done", in: "zero-dev-container")

        // Then
        XCTAssertEqual(mockRunner.executedScript, "cd /workspace && git commit -m 'feat: it'\"'\"'s done'")
    }
}
