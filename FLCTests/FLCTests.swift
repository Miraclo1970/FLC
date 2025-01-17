//
//  FLCTests.swift
//  FLCTests
//
//  Created by Mirko van Velden on 13/12/2024.
//

import Testing
@testable import FLC

struct FLCTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testClusterDataReadinessNormalization() async throws {
        // Test case 1: Normal valid readiness value
        let data1 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Cluster1",
            migrationClusterReadiness: "Ready to start"
        )
        #expect(data1.isValid)
        #expect(data1.migrationClusterReadiness == "Ready to start")
        
        // Test case 2: N/A value should be normalized to nil
        let data2 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Cluster1",
            migrationClusterReadiness: "N/A"
        )
        #expect(data2.isValid)
        #expect(data2.migrationClusterReadiness == nil)
        
        // Test case 3: Whitespace should be trimmed
        let data3 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Cluster1",
            migrationClusterReadiness: "  Planned  "
        )
        #expect(data3.isValid)
        #expect(data3.migrationClusterReadiness == "Planned")
        
        // Test case 4: Invalid readiness value
        let data4 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Cluster1",
            migrationClusterReadiness: "Invalid Status"
        )
        #expect(!data4.isValid)
        #expect(data4.validationErrors.contains { $0.contains("Invalid Migration Cluster Readiness value") })
        
        // Test case 5: Empty department should be invalid
        let data5 = ClusterData(
            department: "",
            migrationCluster: "Cluster1",
            migrationClusterReadiness: "Planned"
        )
        #expect(!data5.isValid)
        #expect(data5.validationErrors.contains("Department is required"))
        
        // Test case 6: Empty migration cluster should be normalized to nil
        let data6 = ClusterData(
            department: "Test Dept",
            migrationCluster: "",
            migrationClusterReadiness: "Planned"
        )
        #expect(data6.isValid)
        #expect(data6.migrationCluster == nil)
        
        // Test case 7: Empty readiness value should be normalized to nil
        let data7 = ClusterData(
            department: "Test Dept",
            migrationCluster: "Cluster1",
            migrationClusterReadiness: ""
        )
        #expect(data7.isValid)
        #expect(data7.migrationClusterReadiness == nil)
    }

    @Test func testProgressRounding() async throws {
        // Test progress cell rounding
        let cell = OverallProgressCell(progress: 79.99999)
        #expect(cell.stableProgress == 80.0)
        #expect(cell.statusText == "In progress")
        
        // Test edge cases
        let cell2 = OverallProgressCell(progress: 20.00001)
        #expect(cell2.stableProgress == 20.0)
        #expect(cell2.statusText == "Started")
        
        let cell3 = OverallProgressCell(progress: 80.00001)
        #expect(cell3.stableProgress == 80.0)
        #expect(cell3.statusText == "In progress")
    }

}
