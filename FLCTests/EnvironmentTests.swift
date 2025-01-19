import XCTest
@testable import FLC

final class EnvironmentTests: XCTestCase {
    var databaseManager: DatabaseManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        databaseManager = DatabaseManager.shared
    }
    
    override func tearDownWithError() throws {
        databaseManager = nil
        try super.tearDownWithError()
    }
    
    func testEnvironmentCases() {
        // Test all environment cases exist
        let environments = Environment.allCases
        XCTAssertEqual(environments.count, 4)
        XCTAssertTrue(environments.contains(.development))
        XCTAssertTrue(environments.contains(.test))
        XCTAssertTrue(environments.contains(.acceptance))
        XCTAssertTrue(environments.contains(.production))
    }
    
    func testEnvironmentDirectories() throws {
        // Test directory creation for each environment
        for environment in Environment.allCases {
            XCTAssertNotNil(environment.baseDirectory)
            XCTAssertNotNil(environment.databaseDirectory)
            XCTAssertNotNil(environment.derivedDataDirectory)
            XCTAssertNotNil(environment.databasePath)
            
            try environment.createDirectories()
            
            // Verify directories exist
            XCTAssertTrue(FileManager.default.fileExists(atPath: environment.baseDirectory!.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: environment.databaseDirectory!.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: environment.derivedDataDirectory!.path))
        }
    }
    
    func testEnvironmentSwitching() async throws {
        // Test switching between environments
        let initialEnvironment = databaseManager.currentEnvironment
        
        // Switch to each environment and verify
        for environment in Environment.allCases where environment != initialEnvironment {
            try await databaseManager.switchEnvironment(to: environment)
            XCTAssertEqual(databaseManager.currentEnvironment, environment)
            
            // Verify database path is correct
            let dbPath = try databaseManager.getDatabasePath()
            XCTAssertTrue(dbPath.contains(environment.rawValue.lowercased()))
            
            // Verify UserDefaults persistence
            let savedEnv = UserDefaults.standard.string(forKey: "last_environment")
            XCTAssertEqual(savedEnv, environment.rawValue)
        }
    }
    
    func testEnvironmentColors() {
        // Test environment color assignments
        XCTAssertEqual(Environment.development.displayColor, .blue)
        XCTAssertEqual(Environment.test.displayColor, .orange)
        XCTAssertEqual(Environment.acceptance.displayColor, .green)
        XCTAssertEqual(Environment.production.displayColor, .red)
    }
    
    func testEnvironmentPersistence() async throws {
        // Test environment persistence across app restarts
        let testEnvironment = Environment.test
        
        // Switch to test environment
        try await databaseManager.switchEnvironment(to: testEnvironment)
        
        // Simulate app restart by recreating database manager
        databaseManager = nil
        databaseManager = DatabaseManager.shared
        
        // Verify environment was restored
        XCTAssertEqual(databaseManager.currentEnvironment, testEnvironment)
    }
    
    func testProductionEnvironmentFlag() {
        // Test isProduction flag
        XCTAssertFalse(Environment.development.isProduction)
        XCTAssertFalse(Environment.test.isProduction)
        XCTAssertFalse(Environment.acceptance.isProduction)
        XCTAssertTrue(Environment.production.isProduction)
    }
    
    func testDerivedDataPaths() {
        // Test derived data path generation
        let testFile = "test.json"
        
        for environment in Environment.allCases {
            let path = environment.derivedDataPath(for: testFile)
            XCTAssertNotNil(path)
            XCTAssertTrue(path?.lastPathComponent == testFile)
            XCTAssertTrue(path?.path.contains(environment.rawValue.lowercased()) ?? false)
        }
    }
}

// UI Tests for EnvironmentSelectorView
final class EnvironmentSelectorUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    func testEnvironmentSelectorVisibility() {
        // Test that environment selector is visible in toolbar
        XCTAssertTrue(app.buttons["Environment Selector"].exists)
    }
    
    func testEnvironmentSwitching() {
        // Test environment switching through UI
        let envButton = app.buttons["Environment Selector"]
        envButton.tap()
        
        // Test each environment option is available
        for environment in Environment.allCases {
            XCTAssertTrue(app.buttons[environment.rawValue].exists)
        }
        
        // Test switching to Test environment
        app.buttons["Test"].tap()
        XCTAssertTrue(app.staticTexts["Test"].exists)
    }
    
    func testEnvironmentPersistenceAfterRelaunch() {
        // Test environment persistence after app relaunch
        let envButton = app.buttons["Environment Selector"]
        envButton.tap()
        app.buttons["Test"].tap()
        
        // Terminate and relaunch
        app.terminate()
        app.launch()
        
        // Verify environment persisted
        XCTAssertTrue(app.staticTexts["Test"].exists)
    }
} 