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

    private func makeService(runner: GitPanelMockContainerRunner) -> GitPanelService {
        let service = GitPanelService()
        service.setup(gitService: GitService(runner: runner), containerName: "zero-dev-container")
        return service
    }
}
