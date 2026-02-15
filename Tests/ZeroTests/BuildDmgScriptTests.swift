import XCTest
@testable import Zero

final class BuildDmgScriptTests: XCTestCase {
    func testBuildDmgScriptDetectsArchitectureDynamically() throws {
        // Given
        let script = try loadBuildScript()

        // Then
        XCTAssertTrue(script.contains("uname -m"))
        XCTAssertFalse(script.contains(".build/arm64-apple-macosx/release"))
    }

    func testBuildDmgScriptDoesNotDependOnMachineLocalIconPath() throws {
        // Given
        let script = try loadBuildScript()

        // Then
        XCTAssertFalse(script.contains("/Users/"))
        XCTAssertTrue(script.contains("Sources/Zero/Resources"))
    }

    private func loadBuildScript(file: StaticString = #filePath) throws -> String {
        let testFileURL = URL(fileURLWithPath: String(describing: file))
        let repositoryRootURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = repositoryRootURL
            .appendingPathComponent("scripts")
            .appendingPathComponent("build_dmg.sh")

        return try String(contentsOf: scriptURL, encoding: .utf8)
    }
}
