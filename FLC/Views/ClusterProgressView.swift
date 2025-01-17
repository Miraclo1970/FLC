import SwiftUI
import GRDB

extension NSColor {
    static let lightBlue = NSColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1.0)
    static let mediumBlue = NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
    static let darkBlue = NSColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
    static let lightOrange = NSColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0)
    static let orange = NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
    static let lightGreen = NSColor(red: 0.6, green: 0.9, blue: 0.6, alpha: 1.0)
    static let green = NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0)
    static let darkGreen = NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
}

struct ClusterSummary {
    let cluster: String
    let applications: Int
    let users: Int
    let packageProgress: Double
    let testProgress: Double
    let packageReadyDate: Date?
    let testReadyDate: Date?
    let combinedProgress: Double
    let status: String
    let migrationClusterReadiness: String?
}

struct MigrationReadinessCell: View {
    let readiness: String?
    
    private var displayText: String {
        guard let value = readiness, !value.isEmpty else {
            return ""
        }
        return value == "Decharge" ? "Decharge 🏁" : value
    }
    
    private var backgroundColor: Color {
        guard let value = readiness, !value.isEmpty else {
            return .clear  // No color for empty value
        }
        
        switch value {
        case "Orderlist to Dep":
            return Color(.lightBlue)
        case "Orderlist Confirmed":
            return Color(.mediumBlue)
        case "Waiting for Apps":
            return Color(.lightOrange)
        case "On Hold":
            return Color(.orange)
        case "Ready to start":
            return Color(.darkBlue)
        case "Planned":
            return Color(.lightGreen)
        case "Executed":
            return Color(.green)
        case "Aftercare OK":
            return Color(.darkGreen)
        case "Decharge":
            return Color(.darkGreen)
        default:
            return .clear
        }
    }
    
    var body: some View {
        Text(displayText)
            .frame(width: 150, alignment: .center)
            .background(backgroundColor.opacity(0.3))
            .cornerRadius(4)
    }
}

struct ClusterProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var selectedCluster: String = ""
    @State private var selectedDivision: String = ""
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
    private var clusters: [String] {
        var clusterSet = Set(records.compactMap { $0.migrationCluster })
        clusterSet.insert("All")
        return Array(clusterSet).sorted()
    }
    
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var filteredRecords: [CombinedRecord] {
        records.filter { record in
            (selectedCluster.isEmpty || selectedCluster == "All" || record.migrationCluster == selectedCluster) &&
            (selectedDivision.isEmpty || record.division == selectedDivision)
        }
    }
    
    private var departments: [String] {
        Array(Set(filteredRecords.compactMap { $0.departmentSimple }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private func calculateClusterTotals(from departmentStats: [ClusterSummary]) -> (applications: Int, users: Int, packageProgress: Double, testProgress: Double, overallProgress: Double, packageReadyDate: Date?, testReadyDate: Date?, migrationClusterReadiness: String?) {
        let totalApplications = departmentStats.reduce(0) { $0 + $1.applications }
        let totalUsers = departmentStats.reduce(0) { $0 + $1.users }
        
        var totalWeightedPackageProgress = 0.0
        var totalWeightedTestProgress = 0.0
        var totalWeight = 0
        
        for stats in departmentStats {
            let weight = stats.applications
            totalWeightedPackageProgress += stats.packageProgress * Double(weight)
            totalWeightedTestProgress += stats.testProgress * Double(weight)
            totalWeight += weight
        }
        
        // Round all progress values to whole numbers
        let avgPackageProgress = totalWeight > 0 ? round(totalWeightedPackageProgress / Double(totalWeight)) : 0.0
        let avgTestProgress = totalWeight > 0 ? round(totalWeightedTestProgress / Double(totalWeight)) : 0.0
        let combinedProgress = round((avgPackageProgress + avgTestProgress) / 2.0)
        
        let latestPackageDate = departmentStats.compactMap { $0.packageReadyDate }.max()
        let latestTestDate = departmentStats.compactMap { $0.testReadyDate }.max()
        
        let readinessValues = departmentStats.compactMap { $0.migrationClusterReadiness }
        let mostCommonReadiness = readinessValues
            .reduce(into: [:]) { counts, value in counts[value, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?
            .key
        
        return (totalApplications, totalUsers, avgPackageProgress, avgTestProgress, combinedProgress, latestPackageDate, latestTestDate, mostCommonReadiness)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Cluster and Division Filters
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cluster Progress")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Division:")
                                .font(.subheadline)
                            Picker("", selection: $selectedDivision) {
                                Text("Select Division").tag("")
                                ForEach(divisions, id: \.self) { division in
                                    Text(division).tag(division)
                                }
                            }
                            .frame(width: 200)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Cluster:")
                                .font(.subheadline)
                            Picker("", selection: $selectedCluster) {
                                Text("Select Cluster").tag("")
                                ForEach(clusters, id: \.self) { cluster in
                                    Text(cluster).tag(cluster)
                                }
                            }
                            .frame(width: 200)
                        }
                    }
                }
                .padding(.bottom, 8)
                
                if !selectedCluster.isEmpty {
                    ScrollView {
                        VStack(spacing: 8) {
                            // Header
                            HStack(spacing: 0) {
                                Text("Migration Cluster")
                                    .frame(width: 350, alignment: .leading)
                                    .padding(.leading, 8)
                                Text("Department")
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
                                Text("Cluster Migration Readiness")
                                    .frame(width: 150, alignment: .center)
                            }
                            .frame(width: 1240)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Cluster total row
                            let departmentStats = departments.map { department in
                                let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                                return calculateStats(for: departmentRecords)
                            }
                            
                            let totals = calculateClusterTotals(from: departmentStats)
                            
                            HStack(spacing: 0) {
                                Text(selectedCluster == "All" ? "Total All Clusters" : "Total \(selectedCluster)")
                                    .bold()
                                    .frame(width: 350, alignment: .leading)
                                    .padding(.leading, 8)
                                Text("")  // Empty Department for total
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
                                MigrationReadinessCell(readiness: totals.migrationClusterReadiness)
                                    .frame(width: 150)
                            }
                            .frame(width: 1240)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            // Department rows
                            ForEach(departments, id: \.self) { department in
                                let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                                let stats = calculateStats(for: departmentRecords)
                                let clusterName = selectedCluster == "All" ? (departmentRecords.first?.migrationCluster ?? "") : selectedCluster
                                HStack(spacing: 0) {
                                    Text(clusterName)
                                        .frame(width: 350, alignment: .leading)
                                        .padding(.leading, 8)
                                    Text(department)
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
                                    MigrationReadinessCell(readiness: stats.migrationClusterReadiness)
                                        .frame(width: 150)
                                }
                                .frame(width: 1240)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }
                    }
                } else {
                    Text("Please select a cluster")
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Export Bar
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Text("Export Cluster Progress Report")
                            .font(.headline)
                        
                        Spacer()
                        
                        if let error = exportError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: exportAsCSV) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.down.doc")
                                }
                                Text("Export to CSV")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting || selectedCluster.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .padding()
        .task {
            await loadData()
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    private func calculateStats(for records: [CombinedRecord]) -> ClusterSummary {
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
        
        // Round all progress values to whole numbers
        let packageProgress = totalApps > 0 ? round(totalPackagePoints / totalApps) : 0.0
        let testProgress = totalApps > 0 ? round(totalTestPoints / totalApps) : 0.0
        
        // Calculate combined progress (only package and test)
        let combinedProgress = round((packageProgress + testProgress) / 2.0)
        
        let packageReadyDate = records.compactMap { $0.applicationPackageReadinessDate }.max()
        let testReadyDate = records.compactMap { $0.applicationTestReadinessDate }.max()
        
        return ClusterSummary(
            cluster: selectedCluster,
            applications: uniqueApps,
            users: uniqueUsers,
            packageProgress: packageProgress,
            testProgress: testProgress,
            packageReadyDate: packageReadyDate,
            testReadyDate: testReadyDate,
            combinedProgress: combinedProgress,
            status: determineStatus(progress: combinedProgress),
            migrationClusterReadiness: records.first?.migrationClusterReadiness
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
    
    private func loadData() async {
        do {
            isLoading = true
            records = try await databaseManager.fetchAllRecords()
        } catch {
            print("Error loading records: \(error)")
        }
        isLoading = false
    }
    
    private func exportAsCSV() {
        isExporting = true
        exportError = nil
        
        Task {
            do {
                // Get save location from user
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = selectedCluster == "All" ? "all_clusters_progress.csv" : "cluster_progress_\(selectedCluster).csv"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = panel.url {
                    // Create CSV content
                    var csvContent = "Migration Cluster,Department,Applications,Users,Package Progress,Package Ready By,Testing Progress,Test Ready By,Overall Progress\n"
                    
                    // Add department rows
                    for department in departments {
                        let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                        let stats = calculateStats(for: departmentRecords)
                        
                        let fields = [
                            selectedCluster,
                            department,
                            String(stats.applications),
                            String(stats.users),
                            String(format: "%.1f", stats.packageProgress),
                            stats.packageReadyDate.map { formatDate($0) } ?? "",
                            String(format: "%.1f", stats.testProgress),
                            stats.testReadyDate.map { formatDate($0) } ?? "",
                            String(format: "%.1f", stats.combinedProgress)
                        ].map { field in
                            // Escape fields that contain commas or quotes
                            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                            return "\"\(escaped)\""
                        }
                        
                        csvContent += fields.joined(separator: ",") + "\n"
                    }
                    
                    // Add cluster totals
                    let departmentStats = departments.map { department in
                        let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                        return calculateStats(for: departmentRecords)
                    }
                    
                    let totals = calculateClusterTotals(from: departmentStats)
                    
                    csvContent += "\nCluster Summary\n"
                    csvContent += "Total Applications,\(totals.applications)\n"
                    csvContent += "Total Users,\(totals.users)\n"
                    csvContent += "Average Package Progress,\(String(format: "%.1f", totals.packageProgress))%\n"
                    csvContent += "Average Testing Progress,\(String(format: "%.1f", totals.testProgress))%\n"
                    csvContent += "Overall Progress,\(String(format: "%.1f", totals.overallProgress))%\n"
                    
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isExporting = false
            }
        }
    }
}

#Preview {
    ClusterProgressView()
        .environmentObject(DatabaseManager.shared)
} 