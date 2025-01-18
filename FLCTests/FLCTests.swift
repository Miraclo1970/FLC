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
}
