import SwiftUI
import GRDB

struct DivisionSummary {
    let division: String
    let applications: Int
    let users: Int
    let packageProgress: Double
    let testProgress: Double
    let packageReadyDate: Date?
    let testReadyDate: Date?
    let combinedProgress: Double
    let status: String
}

struct DivisionProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var selectedDivision: String = ""
    @State private var selectedCluster: String = "All"
    @State private var isLoading = true
    
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var clusters: [String] {
        var clusterSet = Set(records.compactMap { $0.migrationCluster })
        clusterSet.insert("All")
        return Array(clusterSet).sorted()
    }
    
    private var filteredRecords: [CombinedRecord] {
        records.filter { record in
            record.division == selectedDivision &&
            (selectedCluster == "All" || record.migrationCluster == selectedCluster)
        }
    }
    
    private var departments: [String] {
        Array(Set(filteredRecords.compactMap { $0.departmentSimple }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private func calculateDivisionTotals(from departmentStats: [DivisionSummary]) -> (applications: Int, users: Int, packageProgress: Double, testProgress: Double, overallProgress: Double, packageReadyDate: Date?, testReadyDate: Date?) {
        // Simple sum for applications and users
        let totalApplications = departmentStats.reduce(0) { $0 + $1.applications }
        let totalUsers = departmentStats.reduce(0) { $0 + $1.users }
        
        // Calculate weighted averages based on number of applications
        var totalWeightedPackageProgress = 0.0
        var totalWeightedTestProgress = 0.0
        var totalWeight = 0
        
        for stats in departmentStats {
            let weight = stats.applications
            totalWeightedPackageProgress += stats.packageProgress * Double(weight)
            totalWeightedTestProgress += stats.testProgress * Double(weight)
            totalWeight += weight
        }
        
        let avgPackageProgress = totalWeight > 0 ? totalWeightedPackageProgress / Double(totalWeight) : 0.0
        let avgTestProgress = totalWeight > 0 ? totalWeightedTestProgress / Double(totalWeight) : 0.0
        let overallProgress = (avgPackageProgress + avgTestProgress) / 2.0
        
        let latestPackageDate = departmentStats.compactMap { $0.packageReadyDate }.max()
        let latestTestDate = departmentStats.compactMap { $0.testReadyDate }.max()
        
        return (totalApplications, totalUsers, avgPackageProgress, avgTestProgress, overallProgress, latestPackageDate, latestTestDate)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Division and Cluster Filters
                VStack(alignment: .leading, spacing: 12) {
                    Text("Division Progress")
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        Text("Division:")
                            .font(.subheadline)
                        Picker("", selection: $selectedDivision) {
                            ForEach(divisions, id: \.self) { division in
                                Text(division).tag(division)
                            }
                        }
                        .frame(width: 200)
                    }
                }
                .padding(.bottom, 8)
                
                if !selectedDivision.isEmpty {
                    ScrollView {
                        VStack(spacing: 8) {
                            // Header
                            HStack(spacing: 0) {
                                Text("Department")
                                    .frame(width: 350, alignment: .leading)
                                    .padding(.leading, 8)
                                Text("Migration Cluster")
                                    .frame(width: 120, alignment: .leading)
                                Text("Apps")
                                    .frame(width: 60, alignment: .center)
                                Text("Users")
                                    .frame(width: 60, alignment: .center)
                                VStack(spacing: 0) {
                                    Text("Average")
                                    Text("Package")
                                }
                                .frame(width: 120, alignment: .center)
                                Text("Ready by")
                                    .frame(width: 70, alignment: .center)
                                VStack(spacing: 0) {
                                    Text("Average")
                                    Text("Testing")
                                }
                                .frame(width: 120, alignment: .center)
                                Text("Ready by")
                                    .frame(width: 70, alignment: .center)
                                Text("Progress")
                                    .frame(width: 120, alignment: .center)
                            }
                            .frame(width: 1090)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Division total row
                            let departmentStats = departments.map { department in
                                let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                                return calculateStats(for: departmentRecords)
                            }
                            
                            let totals = calculateDivisionTotals(from: departmentStats)
                            
                            HStack(spacing: 0) {
                                Text("Total \(selectedDivision)")
                                    .bold()
                                    .frame(width: 350, alignment: .leading)
                                    .padding(.leading, 8)
                                Text("")  // Empty Migration Cluster for total
                                    .frame(width: 120, alignment: .leading)
                                Text("\(totals.applications)")
                                    .bold()
                                    .frame(width: 60, alignment: .center)
                                Text("\(totals.users)")
                                    .bold()
                                    .frame(width: 60, alignment: .center)
                                AverageProgressCell(progress: totals.packageProgress)
                                    .frame(width: 120)
                                Text(formatDate(totals.packageReadyDate))
                                    .bold()
                                    .frame(width: 70, alignment: .center)
                                    .font(.system(size: 11))
                                AverageProgressCell(progress: totals.testProgress)
                                    .frame(width: 120)
                                Text(formatDate(totals.testReadyDate))
                                    .bold()
                                    .frame(width: 70, alignment: .center)
                                    .font(.system(size: 11))
                                OverallProgressCell(progress: totals.overallProgress)
                                    .frame(width: 120)
                            }
                            .frame(width: 1090)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            // Department rows
                            ForEach(departments, id: \.self) { department in
                                let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                                let stats = calculateStats(for: departmentRecords)
                                let migrationCluster = departmentRecords.first?.migrationCluster ?? ""
                                HStack(spacing: 0) {
                                    Text(department)
                                        .frame(width: 350, alignment: .leading)
                                        .padding(.leading, 8)
                                    Text(migrationCluster)
                                        .frame(width: 120, alignment: .leading)
                                    Text("\(stats.applications)")
                                        .frame(width: 60, alignment: .center)
                                    Text("\(stats.users)")
                                        .frame(width: 60, alignment: .center)
                                    AverageProgressCell(progress: stats.packageProgress)
                                        .frame(width: 120)
                                    Text(formatDate(stats.packageReadyDate))
                                        .frame(width: 70, alignment: .center)
                                        .font(.system(size: 11))
                                    AverageProgressCell(progress: stats.testProgress)
                                        .frame(width: 120)
                                    Text(formatDate(stats.testReadyDate))
                                        .frame(width: 70, alignment: .center)
                                        .font(.system(size: 11))
                                    OverallProgressCell(progress: stats.combinedProgress)
                                        .frame(width: 120)
                                }
                                .frame(width: 1090)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }
                    }
                } else {
                    Text("Please select a division")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .task {
            do {
                isLoading = true
                records = try await databaseManager.fetchAllRecords()
                if let firstDivision = divisions.first {
                    selectedDivision = firstDivision
                }
                isLoading = false
            } catch {
                print("Error loading records: \(error)")
                isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    private func calculateStats(for records: [CombinedRecord]) -> DivisionSummary {
        let uniqueApps = Set(records.map { $0.applicationName }).count
        let uniqueUsers = Set(records.compactMap { $0.systemAccount }).count
        
        // First, filter out applications that are out of scope or have a "will be" value
        let activeRecords = records.filter { record in
            let willBe = record.willBe ?? ""
            let inOutScope = record.inScopeOutScopeDivision?.lowercased() ?? ""
            return (willBe.isEmpty || willBe == "N/A") && inOutScope != "out"
        }
        
        // Group by application name
        let groupedByApp = Dictionary(grouping: activeRecords) { $0.applicationName }
        
        // Calculate package progress
        var totalPackagePoints = 0.0
        var totalTestPoints = 0.0
        let totalApps = Double(groupedByApp.count)
        
        for (_, appRecords) in groupedByApp {
            guard let firstRecord = appRecords.first else { continue }
            
            // Package progress
            let packageStatus = firstRecord.applicationPackageStatus?.lowercased() ?? ""
            if packageStatus == "ready" || packageStatus == "ready for testing" || packageStatus == "completed" || packageStatus == "passed" {
                totalPackagePoints += 100.0
            } else if packageStatus == "in progress" {
                totalPackagePoints += 50.0
            }
            
            // Test progress
            let testStatus = firstRecord.applicationTestStatus?.lowercased() ?? ""
            if testStatus == "ready" || testStatus == "completed" || testStatus == "passed" {
                totalTestPoints += 100.0
            } else if testStatus == "in progress" {
                totalTestPoints += 50.0
            }
        }
        
        let packageProgress = totalApps > 0 ? totalPackagePoints / totalApps : 0.0
        let testProgress = totalApps > 0 ? totalTestPoints / totalApps : 0.0
        let combinedProgress = (packageProgress + testProgress) / 2.0
        
        let packageReadyDate = records.compactMap { $0.applicationPackageReadinessDate }.max()
        let testReadyDate = records.compactMap { $0.applicationTestReadinessDate }.max()
        
        return DivisionSummary(
            division: selectedDivision,
            applications: uniqueApps,
            users: uniqueUsers,
            packageProgress: packageProgress,
            testProgress: testProgress,
            packageReadyDate: packageReadyDate,
            testReadyDate: testReadyDate,
            combinedProgress: combinedProgress,
            status: determineStatus(progress: combinedProgress)
        )
    }
    
    private func determineStatus(progress: Double) -> String {
        switch progress {
        case 0:
            return "Not Started"
        case 100:
            return "Migration ready"
        default:
            return "In Progress"
        }
    }
}

#Preview {
    DivisionProgressView()
        .environmentObject(DatabaseManager.shared)
} 