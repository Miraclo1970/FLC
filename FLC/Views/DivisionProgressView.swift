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
    @AppStorage("divisionView.selectedDivision") private var selectedDivision: String = ""
    @AppStorage("divisionView.excludeNonActive") private var excludeNonActive: Bool = false
    @AppStorage("divisionView.excludeNoHRMatch") private var excludeNoHRMatch: Bool = false
    @AppStorage("divisionView.excludeLeftUsers") private var excludeLeftUsers: Bool = false
    @AppStorage("divisionView.showResults") private var showResults: Bool = false
    @AppStorage("divisionView.sortColumn") private var sortColumnRaw: String = "name"
    @AppStorage("divisionView.sortAscending") private var sortAscending: Bool = true
    @State private var records: [CombinedRecord] = []
    @State private var selectedCluster: String = "All"
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
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
                    
                    // Status Filters
                    VStack(alignment: .leading) {
                        Text("Status:")
                            .font(.subheadline)
                        Toggle("Exclude Sunset & Out of scope", isOn: $excludeNonActive)
                            .toggleStyle(.checkbox)
                        Toggle("Exclude users without HR match", isOn: $excludeNoHRMatch)
                            .toggleStyle(.checkbox)
                        Toggle("Exclude users who have left", isOn: $excludeLeftUsers)
                            .toggleStyle(.checkbox)
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
                
                Spacer()
                
                // Export Bar
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Text("Export Division Progress Report")
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
                        .disabled(isExporting || selectedDivision.isEmpty)
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
    
    private func calculateStats(for records: [CombinedRecord]) -> DivisionSummary {
        // Apply HR match and leave date filters
        let filteredRecords = records.filter { record in
            // HR match filter - check both nil and empty string cases
            let hrFilter = !excludeNoHRMatch || (record.department != nil && !record.department!.isEmpty)
            
            // Leave date filter - only include users who haven't left
            let leaveFilter = !excludeLeftUsers || (record.leaveDate == nil || record.leaveDate! > Date())
            
            return hrFilter && leaveFilter
        }

        // Group by application
        let groupedByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
        // Calculate totals
        let totalApplications = groupedByApp.count
        let uniqueUsers = Set(filteredRecords.map { $0.systemAccount }).count
        
        // Calculate package progress
        let packageProgress = calculatePackageProgress(from: groupedByApp)
        
        // Calculate test progress
        let testProgress = calculateTestProgress(from: groupedByApp)
        
        // Get latest dates
        let packageReadyDate = filteredRecords.compactMap { $0.applicationPackageReadinessDate }.max()
        let testReadyDate = filteredRecords.compactMap { $0.applicationTestReadinessDate }.max()
        
        // Calculate combined progress
        let combinedProgress = (packageProgress + testProgress) / 2.0
        
        // Determine status
        let status = determineStatus(progress: combinedProgress)
        
        return DivisionSummary(
            division: filteredRecords.first?.division ?? "",
            applications: totalApplications,
            users: uniqueUsers,
            packageProgress: packageProgress,
            testProgress: testProgress,
            packageReadyDate: packageReadyDate,
            testReadyDate: testReadyDate,
            combinedProgress: combinedProgress,
            status: status
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
            if let firstDivision = divisions.first {
                selectedDivision = firstDivision
            }
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
                panel.nameFieldStringValue = "division_progress_\(selectedDivision).csv"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = panel.url {
                    // Create CSV content
                    var csvContent = "Department,Migration Cluster,Applications,Users,Package Progress,Package Ready By,Testing Progress,Test Ready By,Overall Progress\n"
                    
                    // Add department rows
                    for department in departments {
                        let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                        let stats = calculateStats(for: departmentRecords)
                        let migrationCluster = departmentRecords.first?.migrationCluster ?? ""
                        
                        let fields = [
                            department,
                            migrationCluster,
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
                    
                    // Add division totals
                    let departmentStats = departments.map { department in
                        let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                        return calculateStats(for: departmentRecords)
                    }
                    
                    let totals = calculateDivisionTotals(from: departmentStats)
                    
                    csvContent += "\nDivision Summary\n"
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
    
    private func calculatePackageProgress(from groupedByApp: [String: [CombinedRecord]]) -> Double {
        var totalPoints = 0.0
        let totalApps = Double(groupedByApp.count)
        
        for (_, appRecords) in groupedByApp {
            guard let firstRecord = appRecords.first else { continue }
            
            let packageStatus = firstRecord.applicationPackageStatus?.lowercased() ?? ""
            if packageStatus == "ready" || packageStatus == "ready for testing" || packageStatus == "completed" || packageStatus == "passed" {
                totalPoints += 100.0
            } else if packageStatus == "in progress" {
                totalPoints += 50.0
            }
        }
        
        return totalApps > 0 ? totalPoints / totalApps : 0.0
    }
    
    private func calculateTestProgress(from groupedByApp: [String: [CombinedRecord]]) -> Double {
        var totalPoints = 0.0
        let totalApps = Double(groupedByApp.count)
        
        for (_, appRecords) in groupedByApp {
            guard let firstRecord = appRecords.first else { continue }
            
            let testStatus = firstRecord.applicationTestStatus?.lowercased() ?? ""
            if testStatus == "ready" || testStatus == "completed" || testStatus == "passed" {
                totalPoints += 100.0
            } else if testStatus == "in progress" {
                totalPoints += 50.0
            }
        }
        
        return totalApps > 0 ? totalPoints / totalApps : 0.0
    }
}

#Preview {
    DivisionProgressView()
        .environmentObject(DatabaseManager.shared)
} 