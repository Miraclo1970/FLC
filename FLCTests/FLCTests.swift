//
//  FLCTests.swift
//  FLCTests
//
//  Created by Mirko van Velden on 13/12/2024.
//

import XCTest
import SwiftUI
@testable import FLC

final class FLCTests: XCTestCase {
    func testExample() async throws {
        // Write your test here
    }
    
    func testClusterDataReadinessNormalization() async throws {
        // Test case 1: Normal valid readiness value
        let data1 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: "Ready to start"
        )
        XCTAssertTrue(data1.isValid)
        XCTAssertEqual(data1.migrationClusterReadiness, "Ready to start")
        
        // Test case 2: N/A value should be normalized to nil
        let data2 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: "N/A"
        )
        XCTAssertTrue(data2.isValid)
        XCTAssertNil(data2.migrationClusterReadiness)
        
        // Test case 3: Whitespace should be trimmed
        let data3 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: "  Planned  "
        )
        XCTAssertTrue(data3.isValid)
        XCTAssertEqual(data3.migrationClusterReadiness, "Planned")
        
        // Test case 4: Invalid readiness value
        let data4 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: "Invalid Status"
        )
        XCTAssertFalse(data4.isValid)
        XCTAssertTrue(data4.validationErrors.contains { $0.contains("Invalid Migration Cluster Readiness value") })
        
        // Test case 5: Empty department should be invalid
        let data5 = ClusterData(
            department: "",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: "Planned"
        )
        XCTAssertFalse(data5.isValid)
        XCTAssertTrue(data5.validationErrors.contains("Department is required"))
        
        // Test case 6: Empty migration cluster should be normalized to nil
        let data6 = ClusterData(
            department: "Test Dept",
            migrationCluster: "",
            migrationClusterReadiness: "Planned"
        )
        XCTAssertTrue(data6.isValid)
        XCTAssertNil(data6.migrationCluster)
        
        // Test case 7: Empty readiness value should be normalized to nil
        let data7 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: ""
        )
        XCTAssertTrue(data7.isValid)
        XCTAssertNil(data7.migrationClusterReadiness)
    }
    
    @MainActor
    func testProgressRounding() throws {
        // Test progress cell rounding by checking the status text
        let cell = OverallProgressCell(progress: 79.99999)
        XCTAssertEqual(cell.statusText, "In progress")
        
        // Test edge cases
        let cell2 = OverallProgressCell(progress: 20.00001)
        XCTAssertEqual(cell2.statusText, "Started")
        
        let cell3 = OverallProgressCell(progress: 81.00001)
        XCTAssertEqual(cell3.statusText, "Finishing")
    }
    
    @MainActor
    func testMigrationDataValidation() async throws {
        // Setup test data in DatabaseManager
        let dbManager = DatabaseManager.shared
        try await dbManager.setupTestData()
        
        // Test case 1: Valid migration data without "Will be"
        let data1 = MigrationData(
            applicationName: "TestApp1",  // Exists in AD
            willBe: "N/A"
        )
        XCTAssertTrue(data1.isValid)
        XCTAssertTrue(data1.validationErrors.isEmpty)
        
        // Test case 2: Application not in AD
        let data2 = MigrationData(
            applicationName: "NonExistentApp",
            willBe: "N/A"
        )
        XCTAssertFalse(data2.isValid)
        XCTAssertTrue(data2.validationErrors.contains { $0.contains("not found in AD records") })
        
        // Test case 3: Valid migration with "Will be" to existing app with users
        let data3 = MigrationData(
            applicationName: "TestApp1",  // Exists in AD
            willBe: "TestApp2"           // Exists in AD with users
        )
        XCTAssertTrue(data3.isValid)
        XCTAssertTrue(data3.validationErrors.isEmpty)
        
        // Test case 4: "Will be" points to non-existent app
        let data4 = MigrationData(
            applicationName: "TestApp1",
            willBe: "NonExistentApp"
        )
        XCTAssertFalse(data4.isValid)
        XCTAssertTrue(data4.validationErrors.contains { $0.contains("Will be application 'NonExistentApp' not found in AD records") })
        
        // Test case 5: "Will be" points to app without users
        let data5 = MigrationData(
            applicationName: "TestApp1",
            willBe: "EmptyApp"  // Exists in AD but no users
        )
        XCTAssertFalse(data5.isValid)
        XCTAssertTrue(data5.validationErrors.contains { $0.contains("has no users in AD") })
        
        // Test case 6: Duplicate application
        let data6 = MigrationData(
            applicationName: "DuplicateApp",  // Already exists in migration records
            willBe: "N/A"
        )
        XCTAssertFalse(data6.isValid)
        XCTAssertTrue(data6.validationErrors.contains { $0.contains("Duplicate Application Name") })
    }
    
    @MainActor
    func testUserMigration() async throws {
        // Setup test data in DatabaseManager
        let dbManager = DatabaseManager.shared
        try await dbManager.setupTestData()
        
        // Create test migration record
        let migrationData = MigrationData(
            applicationName: "TestApp1",  // Has 3 users
            willBe: "TestApp2"           // Has 2 different users
        )
        
        // Import the migration record
        try dbManager.importMigrationRecords([migrationData], importSet: "TestImport")
        
        // Verify users were migrated
        let targetAppUsers = try await dbManager.getADUsers(for: "TestApp2")
        
        // Should now have all unique users from both apps
        XCTAssertEqual(targetAppUsers.count, 5)
        
        // Verify specific test users exist
        XCTAssertTrue(targetAppUsers.contains { $0.systemAccount == "user1" })
        XCTAssertTrue(targetAppUsers.contains { $0.systemAccount == "user2" })
        XCTAssertTrue(targetAppUsers.contains { $0.systemAccount == "user3" })
        XCTAssertTrue(targetAppUsers.contains { $0.systemAccount == "user4" })
        XCTAssertTrue(targetAppUsers.contains { $0.systemAccount == "user5" })
    }
}
