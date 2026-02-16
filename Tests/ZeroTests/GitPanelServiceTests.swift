import XCTest
@testable import Zero

private final class GitPanelMockContainerRunner: ContainerRunning {
    var nextShellOutput = ""
    var shellErrorsByCommandSubstring: [String: Error] = [:]

    func executeCommand(container: String, command: String) throws -> String {
        return ""
    }

    func executeShell(container: String, script: String) throws -> String {
        if let match = shellErrorsByCommandSubstring.first(where: { script.contains($0.key) }) {
            throw match.value
        }
        return nextShellOutput
    }

    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String {
        if let match = shellErrorsByCommandSubstring.first(where: { script.contains($0.key) }) {
            throw match.value
        }
        onOutput(nextShellOutput)
        return nextShellOutput
    }
}

@MainActor
final class GitPanelServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLogStore.shared.clear()
    }

    override func tearDown() {
        AppLogStore.shared.clear()
        super.tearDown()
    }

    func testPushMapsNonFastForwardFailureToGuidance() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.shellErrorsByCommandSubstring["git push"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "! [rejected] main -> main (non-fast-forward)\nerror: failed to push some refs"]
        )
        let service = makeService(runner: runner)

        // When
        await service.push()

        // Then
        XCTAssertEqual(
            service.errorMessage,
            "Push rejected because remote has new commits. Pull, resolve conflicts if needed, then push again."
        )
    }

    func testPullMapsMergeConflictFailureToGuidance() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.nextShellOutput = """
        Sources/Zero/Views/EditorView.swift
        Sources/Zero/Services/GitPanelService.swift
        """
        runner.shellErrorsByCommandSubstring["git pull"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Automatic merge failed; fix conflicts and then commit the result."]
        )
        let service = makeService(runner: runner)

        // When
        await service.pull()

        // Then
        XCTAssertEqual(
            service.errorMessage,
            "Pull hit merge conflicts in Sources/Zero/Views/EditorView.swift, Sources/Zero/Services/GitPanelService.swift. Resolve those files, commit, then pull again."
        )
    }

    func testPullConflictFallsBackToGenericGuidanceWhenNoFilesDetected() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.nextShellOutput = ""
        runner.shellErrorsByCommandSubstring["git pull"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Automatic merge failed; fix conflicts and then commit the result."]
        )
        let service = makeService(runner: runner)

        // When
        await service.pull()

        // Then
        XCTAssertEqual(
            service.errorMessage,
            "Pull hit merge conflicts. Resolve conflicted files, commit, then pull again."
        )
    }

    func testPullMapsAuthenticationFailureToGuidance() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.shellErrorsByCommandSubstring["git pull"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "fatal: Authentication failed for 'https://github.com/zero-ide/Zero.git/'"]
        )
        let service = makeService(runner: runner)

        // When
        await service.pull()

        // Then
        XCTAssertEqual(
            service.errorMessage,
            "Git authentication or permission failed. Verify credentials and repository access, then retry."
        )
    }

    func testPushKeepsOriginalMessageForUnknownFailures() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.shellErrorsByCommandSubstring["git push"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "fatal: unexpected socket close"]
        )
        let service = makeService(runner: runner)

        // When
        await service.push()

        // Then
        XCTAssertEqual(service.errorMessage, "fatal: unexpected socket close")
    }

    func testPushFailureAppendsErrorToAppLogStore() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.shellErrorsByCommandSubstring["git push"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "fatal: unexpected socket close"]
        )
        let service = makeService(runner: runner)

        // When
        await service.push()

        // Then
        let logEntries = AppLogStore.shared.recentEntries()
        XCTAssertTrue(logEntries.contains { entry in
            entry.contains("GitPanel push failed") && entry.contains("fatal: unexpected socket close")
        })
    }

    func testPullConflictAppendsGuidanceToAppLogStore() async {
        // Given
        let runner = GitPanelMockContainerRunner()
        runner.nextShellOutput = "Sources/Zero/Views/EditorView.swift"
        runner.shellErrorsByCommandSubstring["git pull"] = NSError(
            domain: "git",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Automatic merge failed; fix conflicts and then commit the result."]
        )
        let service = makeService(runner: runner)

        // When
        await service.pull()

        // Then
        let logEntries = AppLogStore.shared.recentEntries()
        XCTAssertTrue(logEntries.contains { entry in
            entry.contains("GitPanel pull failed") && entry.contains("Pull hit merge conflicts")
        })
    }

    private func makeService(runner: GitPanelMockContainerRunner) -> GitPanelService {
        let service = GitPanelService()
        service.setup(gitService: GitService(runner: runner), containerName: "zero-dev-container")
        return service
    }
}
