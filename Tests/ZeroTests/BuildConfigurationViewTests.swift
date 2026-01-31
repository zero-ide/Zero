import XCTest
import SwiftUI
import ViewInspector
@testable import Zero

@MainActor
class BuildConfigurationViewTests: XCTestCase {
    
    func testBuildConfigurationViewRenders() throws {
        // Given
        let view = BuildConfigurationView()
        
        // Then
        XCTAssertNoThrow(try view.inspect().find(text: "Build Configuration"))
    }
    
    func testJDKSelectorRenders() throws {
        // Given
        let view = BuildConfigurationView()
        
        // Then
        XCTAssertNoThrow(try view.inspect().find(text: "JDK Image"))
    }
    
    func testBuildToolSelectorRenders() throws {
        // Given
        let view = BuildConfigurationView()
        
        // Then
        XCTAssertNoThrow(try view.inspect().find(text: "Build Tool"))
    }
}

@MainActor
class JDKSelectorViewTests: XCTestCase {
    
    func testJDKSelectorShowsPredefinedOptions() throws {
        // Given
        let config = BuildConfiguration.default
        let view = JDKSelectorView(configuration: .constant(config))
        
        // Then
        XCTAssertNoThrow(try view.inspect().find(Picker.self))
    }
}
