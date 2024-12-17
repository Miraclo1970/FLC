import SwiftUI

@available(macOS 14.0, *)
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
            
            // Save to database
            let adResult = try await DatabaseManager.shared.saveADRecords(adTestData)
            let hrResult = try await DatabaseManager.shared.saveHRRecords(hrTestData)
            let packageResult = try await DatabaseManager.shared.savePackageRecords(packageTestData)
            let testResult = try await DatabaseManager.shared.saveTestRecords(testingData)
            
            message = """
            Imported:
            - \(adResult.saved) AD records
            - \(hrResult.saved) HR records
            - \(packageResult.saved) Package Status records
            - \(testResult.saved) Test records
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
            try await DatabaseManager.shared.clearADRecords()
            try await DatabaseManager.shared.clearHRRecords()
            try await DatabaseManager.shared.clearPackageRecords()
            try await DatabaseManager.shared.clearTestRecords()
            try await DatabaseManager.shared.clearCombinedRecords()
            
            message = "Successfully cleared all test data"
            await checkDatabase()
        } catch {
            message = "Error clearing test data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    if #available(macOS 14.0, *) {
        TestDataGeneratorView()
    } else {
        Text("Only available on macOS 14.0 or newer")
    }
} 