import XCTest
import SwiftUI
@testable import Zero

@MainActor
class BuildConfigurationViewTests: XCTestCase {
    
    func testBuildConfigurationViewExists() {
        // Given & Then
        // View exists and can be instantiated
        let _ = BuildConfigurationView()
    }
    
    func testJDKConfigurationDefault() {
        // Given
        let config = BuildConfiguration.default
        
        // Then
        XCTAssertEqual(config.buildTool, .javac)
        XCTAssertTrue(config.customArgs.isEmpty)
    }
    
    func testJDKPredefinedNotEmpty() {
        // Then
        XCTAssertFalse(JDKConfiguration.predefined.isEmpty)
    }
}

@MainActor
class JDKSelectorViewTests: XCTestCase {
    
    func testJDKSelectorViewExists() {
        // Given
        let config = BuildConfiguration.default
        
        // Then
        // View exists and can be instantiated
        let _ = JDKSelectorView(configuration: .constant(config), isCustomImage: .constant(false), customImage: .constant(""))
    }
}
