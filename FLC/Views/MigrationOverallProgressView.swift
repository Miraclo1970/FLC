import SwiftUI
import GRDB

struct MigrationOverallProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    
    // Current date information
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
    private let currentDate = Date()
    
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    // Helper function to get active production records for a division
    private func activeProductionRecords(for division: String) -> [CombinedRecord] {
        let today = Date()
        return records.filter { record in
            record.otap == "P" &&
            record.division == division &&
            (record.leaveDate == nil || record.leaveDate! > today)
        }
    }
    
    // Progress calculation functions
    private func packageProgress(for division: String) -> Double {
        let divisionRecords = activeProductionRecords(for: division)
        let uniqueApps = Set(divisionRecords.map { $0.applicationName })
        guard !uniqueApps.isEmpty else { return 0.0 }
        
        let appsWithStatus = Set(divisionRecords.filter { record in
            record.applicationPackageStatus == "Ready"
        }.map { $0.applicationName })
        
        return Double(appsWithStatus.count) / Double(uniqueApps.count) * 100.0
    }
    
    private func testingProgress(for division: String) -> Double {
        let divisionRecords = activeProductionRecords(for: division)
        let uniqueApps = Set(divisionRecords.map { $0.applicationName })
        guard !uniqueApps.isEmpty else { return 0.0 }
        
        let appsWithStatus = Set(divisionRecords.filter { record in
            record.applicationTestStatus == "Ready"
        }.map { $0.applicationName })
        
        return Double(appsWithStatus.count) / Double(uniqueApps.count) * 100.0
    }
    
    private func migrationProgress(for division: String) -> Double {
        let divisionRecords = activeProductionRecords(for: division)
        let uniqueApps = Set(divisionRecords.map { $0.applicationName })
        guard !uniqueApps.isEmpty else { return 0.0 }
        
        let appsReady = Set(divisionRecords.filter { record in
            record.migrationReadiness == "Ready"
        }.map { $0.applicationName })
        
        return Double(appsReady.count) / Double(uniqueApps.count) * 100.0
    }
    
    private func clusterReadinessProgress(for division: String) -> Double {
        let divisionRecords = activeProductionRecords(for: division)
        let uniqueApps = Set(divisionRecords.map { $0.applicationName })
        guard !uniqueApps.isEmpty else { return 0.0 }
        
        let appsClusterReady = Set(divisionRecords.filter { record in
            // An app is cluster ready only if all three components are ready
            let hasPackageStatus = record.applicationPackageStatus == "Ready"
            let hasTestStatus = record.applicationTestStatus == "Ready"
            let hasMigrationStatus = record.migrationReadiness == "Ready"
            
            return hasPackageStatus && hasTestStatus && hasMigrationStatus
        }.map { $0.applicationName })
        
        return Double(appsClusterReady.count) / Double(uniqueApps.count) * 100.0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Header
                HStack {
                    Text("Migration Overall Progress")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("OTAP: P")
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    HStack(spacing: 8) {
                        Text("Year: \(currentYear)")
                        Text("Week: \(currentWeek)")
                        Text("Date: \(currentDate, formatter: dateFormatter)")
                    }
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                
                // Progress bars for each division
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(divisions, id: \.self) { division in
                            DivisionProgressSection(
                                division: division,
                                packageProgress: packageProgress(for: division),
                                testingProgress: testingProgress(for: division),
                                migrationProgress: migrationProgress(for: division),
                                clusterReadinessProgress: clusterReadinessProgress(for: division)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter
    }()
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            records = try await databaseManager.fetchCombinedRecords()
        } catch {
            print("Error loading data: \(error)")
        }
    }
}

struct DivisionProgressSection: View {
    let division: String
    let packageProgress: Double
    let testingProgress: Double
    let migrationProgress: Double
    let clusterReadinessProgress: Double
    
    var body: some View {
        HStack(spacing: 20) {
            // Division Name
            Text(division)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 80, alignment: .leading)
            
            // Package Progress
            ProgressGroup(
                label: "Package progress",
                progress: packageProgress
            )
            
            // Testing Progress
            ProgressGroup(
                label: "Testing progress",
                progress: testingProgress
            )
            
            // Migration Progress
            ProgressGroup(
                label: "Migration progress",
                progress: migrationProgress
            )
            
            // Cluster Readiness Progress
            ProgressGroup(
                label: "Cluster readiness",
                progress: clusterReadinessProgress
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            .background(Color.white.opacity(0.5)))
    }
}

struct ProgressGroup: View {
    let label: String
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 6)
                    
                    // Progress dot
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(x: (progress / 100.0) * 74)  // 80 - dot size = 74
                }
                
                Text(String(format: "%.0f%%", progress))
                    .font(.system(size: 11))
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
}

#Preview {
    MigrationOverallProgressView()
        .environmentObject(DatabaseManager.shared)
} 