import XCTest
@testable import Zero

class BuildConfigurationServiceTests: XCTestCase {
    
    var service: BuildConfigurationService!
    let testConfigPath = "/tmp/test-zero-build-config.json"
    
    override func setUp() {
        super.setUp()
        service = FileBasedBuildConfigurationService(configPath: testConfigPath)
        try? FileManager.default.removeItem(atPath: testConfigPath)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testConfigPath)
        super.tearDown()
    }
    
    func testSaveAndLoadConfiguration() throws {
        // Given
        let config = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[0],
            buildTool: .maven,
            customArgs: ["-Xmx2g"]
        )
        
        // When
        try service.save(config)
        let loaded = try service.load()
        
        // Then
        XCTAssertEqual(loaded.selectedJDK.id, config.selectedJDK.id)
        XCTAssertEqual(loaded.buildTool, config.buildTool)
        XCTAssertEqual(loaded.customArgs, config.customArgs)
    }
    
    func testLoadDefaultWhenNoFile() throws {
        // When
        let config = try service.load()
        
        // Then
        XCTAssertEqual(config.buildTool, .javac)
        XCTAssertTrue(config.customArgs.isEmpty)
    }
    
    func testResetToDefault() throws {
        // Given
        let customConfig = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[2],
            buildTool: .gradle,
            customArgs: ["--info"]
        )
        try service.save(customConfig)
        
        // When
        try service.reset()
        let config = try service.load()
        
        // Then
        XCTAssertEqual(config.buildTool, .javac)
    }
}
