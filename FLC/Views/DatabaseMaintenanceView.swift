import SwiftUI

struct DatabaseMaintenanceView: View {
    @State private var dbState = "No data yet"
    @State private var isLoading = false
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Database Maintenance")
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
    
    private func clearAllData() async {
        isLoading = true
        message = "Clearing all data..."
        
        do {
            // Clear all tables
            try await DatabaseManager.shared.clearADRecords()
            try await DatabaseManager.shared.clearHRRecords()
            try await DatabaseManager.shared.clearPackageRecords()
            try await DatabaseManager.shared.clearTestRecords()
            try await DatabaseManager.shared.clearCombinedRecords()
            try await DatabaseManager.shared.clearMigrationRecords()
            try await DatabaseManager.shared.clearClusterRecords()
            
            // Force DatabaseManager to reinitialize
            try await DatabaseManager.shared.reinitialize()
            
            // Check the database state
            await checkDatabase()
            
            message = "Successfully cleared all data"
        } catch {
            message = "Error clearing data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    DatabaseMaintenanceView()
} 