import SwiftUI

struct TestDataGeneratorView: View {
    @State private var dbState = "No data yet"
    @State private var isLoading = false
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Database Test Panel")
                .font(.title)
            
            // Database State
            GroupBox("Database State") {
                ScrollView {
                    Text(dbState)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 300)
            }
            
            // Action Buttons
            HStack(spacing: 20) {
                Button("Check Database") {
                    Task {
                        await checkDatabase()
                    }
                }
                
                Button("Import Test Data") {
                    Task {
                        await importTestData()
                    }
                }
                
                Button("Generate Combined") {
                    Task {
                        await generateCombined()
                    }
                }
                
                Button("Test Updates") {
                    Task {
                        await testUpdates()
                    }
                }
                
                Button("Clear All", role: .destructive) {
                    Task {
                        await clearAllData()
                    }
                }
            }
            
            // Status Message
            if !message.isEmpty {
                Text(message)
                    .foregroundColor(message.contains("Error") ? .red : .green)
                    .padding()
            }
            
            if isLoading {
                ProgressView()
            }
        }
        .padding()
        .onAppear {
            Task {
                await checkDatabase()
            }
        }
    }
    
    private func checkDatabase() async {
        isLoading = true
        do {
            dbState = try await DatabaseManager.shared.checkDatabaseState()
        } catch {
            message = "Error checking database: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func importTestData() async {
        isLoading = true
        message = "Importing test data..."
        
        do {
            // Generate test data
            let adTestData = TestDataGenerator.generateADTestData()
            let hrTestData = TestDataGenerator.generateHRTestData()
            let packageTestData = TestDataGenerator.generatePackageStatusData()
            let testingData = TestDataGenerator.generateTestingData()
            let clusterData = TestDataGenerator.generateClusterTestData()
            
            // Save to database
            let adResult = try await DatabaseManager.shared.saveADRecords(adTestData)
            let hrResult = try await DatabaseManager.shared.saveHRRecords(hrTestData)
            let packageResult = try await DatabaseManager.shared.savePackageRecords(packageTestData)
            let testResult = try await DatabaseManager.shared.saveTestRecords(testingData)
            let clusterResult = try await DatabaseManager.shared.saveClusterRecords(clusterData)
            
            message = """
            Imported:
            - \(adResult.saved) AD records
            - \(hrResult.saved) HR records
            - \(packageResult.saved) Package Status records
            - \(testResult.saved) Test records
            - \(clusterResult.saved) Cluster records
            """
            await checkDatabase()
        } catch {
            message = "Error importing test data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func generateCombined() async {
        isLoading = true
        message = "Generating combined records..."
        
        do {
            let count = try await DatabaseManager.shared.generateCombinedRecords()
            message = "Generated \(count) combined records"
            await checkDatabase()
        } catch {
            message = "Error generating combined records: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func testUpdates() async {
        isLoading = true
        message = "Testing updates..."
        
        do {
            // Get a sample record to update
            let records = try await DatabaseManager.shared.fetchCombinedRecords(limit: 1)
            guard let record = records.first else {
                message = "No records found to test updates"
                isLoading = false
                return
            }
            
            // Test package status update
            try await DatabaseManager.shared.updatePackageStatus(
                forSystemAccount: record.systemAccount,
                adGroup: record.adGroup,
                status: "In Progress"
            )
            
            // Test package readiness date
            try await DatabaseManager.shared.updatePackageReadinessDate(
                forSystemAccount: record.systemAccount,
                adGroup: record.adGroup,
                date: Date().addingTimeInterval(60*60*24*30) // 30 days from now
            )
            
            // Test test status
            try await DatabaseManager.shared.updateTestStatus(
                forSystemAccount: record.systemAccount,
                adGroup: record.adGroup,
                status: "Testing"
            )
            
            // Test migration info
            try await DatabaseManager.shared.updateMigrationCluster(
                forSystemAccount: record.systemAccount,
                adGroup: record.adGroup,
                cluster: "Cluster A"
            )
            
            message = "Successfully tested all updates on record: \(record.systemAccount)"
            await checkDatabase()
        } catch {
            message = "Error testing updates: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func clearAllData() async {
        isLoading = true
        message = "Clearing all test data..."
        
        do {
            // Clear all tables first
            try await DatabaseManager.shared.clearADRecords()
            try await DatabaseManager.shared.clearHRRecords()
            try await DatabaseManager.shared.clearPackageRecords()
            try await DatabaseManager.shared.clearTestRecords()
            try await DatabaseManager.shared.clearCombinedRecords()
            try await DatabaseManager.shared.clearMigrationRecords()
            try await DatabaseManager.shared.clearClusterRecords()
            
            // Get the Application Support directory
            guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find Application Support directory"])
            }
            
            // Get the FLC directory
            let flcDir = appSupportDir.appendingPathComponent("FLC")
            
            // Delete the database file
            let dbPath = flcDir.appendingPathComponent("database.sqlite")
            if FileManager.default.fileExists(atPath: dbPath.path) {
                try FileManager.default.removeItem(at: dbPath)
                message = "Successfully cleared all test data and deleted database file"
            } else {
                message = "Successfully cleared all test data (database file not found)"
            }
            
            // Also delete any journal or temporary files
            let dbPathStr = dbPath.path
            for suffix in ["-wal", "-shm"] {
                let extraFile = dbPathStr + suffix
                if FileManager.default.fileExists(atPath: extraFile) {
                    try FileManager.default.removeItem(atPath: extraFile)
                }
            }
            
            // Add a small delay to ensure files are fully deleted
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Force DatabaseManager to reinitialize
            try await DatabaseManager.shared.reinitialize()
            
            // Now check the database state
            await checkDatabase()
        } catch {
            message = "Error clearing test data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    TestDataGeneratorView()
} 