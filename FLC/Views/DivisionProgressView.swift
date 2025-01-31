import SwiftUI
import GRDB

struct DivisionReport {
    let department: String
    let migrationCluster: String
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
    @AppStorage("divisionView.excludeLeftUsers") private var excludeLeftUsers: Bool = false
    @AppStorage("divisionView.showResults") private var showResults: Bool = false
    @AppStorage("divisionView.sortColumn") private var sortColumnRaw: String = "name"
    @AppStorage("divisionView.sortAscending") private var sortAscending: Bool = true
    @State private var selectedEnvironments: Set<String> = ["P"]  // Default to Production
    @State private var records: [CombinedRecord] = []
    @State private var selectedCluster: String = "All"
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
    private let environments = ["All", "P", "A", "OT"]
    
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
    
    private var divisionReport: [DivisionReport] {
        // First, filter records by division only
        let divisionRecords = records.filter { record in
            // Division filter
            let divisionFilter = selectedDivision == "All" || record.division == selectedDivision
            
            // Environment filter - if "All" is not selected, check against selected environments
            let environmentFilter = selectedEnvironments.contains("All") || 
                (!record.otap.isEmpty && selectedEnvironments.contains(record.otap))
            
            return divisionFilter && environmentFilter
        }
        
        // Then create reports for each department
        return departments.map { department in
            let departmentRecords = divisionRecords.filter { record in
                // Department filter
                guard record.departmentSimple == department else { return false }
                
                // Leave date filter
                let leaveFilter = !excludeLeftUsers || (record.leaveDate == nil || record.leaveDate! > Date())
                
                // Out of scope filter
                let inOutScope = (record.inScopeOutScopeDivision ?? "").lowercased()
                let scopeFilter = {
                    if !excludeNonActive {
                        return true
                    }
                    
                    // Check for sunset
                    if inOutScope == "sunset" {
                        return false
                    }
                    
                    // Check for general "out"
                    if inOutScope == "out" {
                        return false
                    }
                    
                    // Check for "out" followed by division names
                    if inOutScope.starts(with: "out ") {
                        let divisions = inOutScope.dropFirst(4).split(separator: " ").map { String($0).lowercased() }
                        return !divisions.contains(selectedDivision.lowercased())
                    }
                    
                    return true
                }()
                
                return leaveFilter && scopeFilter
            }
            
            // Count unique applications and users
            let uniqueApps = Set(departmentRecords.map { $0.applicationName }).count
            let uniqueUsers = Set(departmentRecords.map { $0.systemAccount }).count
            
            // Group by application for progress calculations
            let groupedByApp = Dictionary(grouping: departmentRecords) { $0.applicationName }
            
            // Calculate progress
            let packageProgress = calculatePackageProgress(from: groupedByApp)
            let testProgress = calculateTestProgress(from: groupedByApp)
            let combinedProgress = (packageProgress + testProgress) / 2.0
            
            return DivisionReport(
                department: department,
                migrationCluster: departmentRecords.first?.migrationCluster ?? "",
                applications: uniqueApps,
                users: uniqueUsers,
                packageProgress: packageProgress,
                testProgress: testProgress,
                packageReadyDate: departmentRecords.compactMap { $0.applicationPackageReadinessDate }.max(),
                testReadyDate: departmentRecords.compactMap { $0.applicationTestReadinessDate }.max(),
                combinedProgress: combinedProgress,
                status: determineStatus(progress: combinedProgress)
            )
        }
    }
    
    private var divisionTotals: (applications: Int, users: Int, packageProgress: Double, testProgress: Double, overallProgress: Double, packageReadyDate: Date?, testReadyDate: Date?) {
        // Get all records for the selected division with filters applied
        let divisionRecords = records.filter { record in
            // Division filter
            let divisionFilter = selectedDivision == "All" || record.division == selectedDivision
            
            // Environment filter - if "All" is not selected, check against selected environments
            let environmentFilter = selectedEnvironments.contains("All") || 
                (!record.otap.isEmpty && selectedEnvironments.contains(record.otap))
            
            guard divisionFilter && environmentFilter else { return false }
            
            // Leave date filter
            let leaveFilter = !excludeLeftUsers || (record.leaveDate == nil || record.leaveDate! > Date())
            
            // Out of scope filter
            let inOutScope = (record.inScopeOutScopeDivision ?? "").lowercased()
            let scopeFilter = {
                if !excludeNonActive {
                    return true
                }
                
                // Check for sunset
                if inOutScope == "sunset" {
                    return false
                }
                
                // Check for general "out"
                if inOutScope == "out" {
                    return false
                }
                
                // Check for "out" followed by division names
                if inOutScope.starts(with: "out ") {
                    let divisions = inOutScope.dropFirst(4).split(separator: " ").map { String($0).lowercased() }
                    return !divisions.contains(selectedDivision.lowercased())
                }
                
                return true
            }()
            
            return leaveFilter && scopeFilter
        }
        
        // Count unique applications and users
        let uniqueApps = Set(divisionRecords.map { $0.applicationName }).count
        let uniqueUsers = Set(divisionRecords.map { $0.systemAccount }).count
        
        // Calculate weighted averages based on department stats
        var totalWeightedPackageProgress = 0.0
        var totalWeightedTestProgress = 0.0
        var totalWeight = 0
        
        for report in divisionReport {
            let weight = report.applications
            totalWeightedPackageProgress += report.packageProgress * Double(weight)
            totalWeightedTestProgress += report.testProgress * Double(weight)
            totalWeight += weight
        }
        
        let avgPackageProgress = totalWeight > 0 ? totalWeightedPackageProgress / Double(totalWeight) : 0.0
        let avgTestProgress = totalWeight > 0 ? totalWeightedTestProgress / Double(totalWeight) : 0.0
        let overallProgress = (avgPackageProgress + avgTestProgress) / 2.0
        
        return (
            uniqueApps,
            uniqueUsers,
            avgPackageProgress,
            avgTestProgress,
            overallProgress,
            divisionReport.compactMap { $0.packageReadyDate }.max(),
            divisionReport.compactMap { $0.testReadyDate }.max()
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Filter Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Division")
                        .font(.headline)
                    
                    HStack(spacing: 40) {
                        // Left column
                        HStack(spacing: 20) {
                            // Division Picker
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
                            
                            // Environment Filter
                            VStack(alignment: .leading) {
                                Text("Environment:")
                                    .font(.subheadline)
                                HStack(spacing: 8) {
                                    ForEach(environments, id: \.self) { env in
                                        Toggle(env, isOn: environmentBinding(for: env))
                                            .toggleStyle(.checkbox)
                                    }
                                }
                            }
                        }
                        
                        // Right column
                        VStack(alignment: .leading) {
                            Text("Status:")
                                .font(.subheadline)
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Exclude Sunset & Out of scope", isOn: $excludeNonActive)
                                    .toggleStyle(.checkbox)
                                Toggle("Exclude users who have left", isOn: $excludeLeftUsers)
                                    .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
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
                                Text("Department Progress")
                                    .frame(width: 120, alignment: .center)
                            }
                            .frame(width: 1090)
                            .padding(.vertical, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Division total row
                            let totals = divisionTotals
                            
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
                            .padding(.vertical, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            // Department rows
                            ForEach(divisionReport, id: \.department) { report in
                                HStack(spacing: 0) {
                                    Text(report.department)
                                        .frame(width: 350, alignment: .leading)
                                        .padding(.leading, 8)
                                    Text(report.migrationCluster)
                                        .frame(width: 120, alignment: .leading)
                                    Text("\(report.applications)")
                                        .frame(width: 60, alignment: .center)
                                    Text("\(report.users)")
                                        .frame(width: 60, alignment: .center)
                                    AverageProgressCell(progress: report.packageProgress)
                                        .frame(width: 120)
                                    Text(formatDate(report.packageReadyDate))
                                        .frame(width: 70, alignment: .center)
                                        .font(.system(size: 11))
                                    AverageProgressCell(progress: report.testProgress)
                                        .frame(width: 120)
                                    Text(formatDate(report.testReadyDate))
                                        .frame(width: 70, alignment: .center)
                                        .font(.system(size: 11))
                                    OverallProgressCell(progress: report.combinedProgress)
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
                    for report in divisionReport {
                        let fields = [
                            report.department,
                            report.migrationCluster,
                            String(report.applications),
                            String(report.users),
                            String(format: "%.1f", report.packageProgress),
                            report.packageReadyDate.map { formatDate($0) } ?? "",
                            String(format: "%.1f", report.testProgress),
                            report.testReadyDate.map { formatDate($0) } ?? "",
                            String(format: "%.1f", report.combinedProgress)
                        ].map { field in
                            // Escape fields that contain commas or quotes
                            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                            return "\"\(escaped)\""
                        }
                        
                        csvContent += fields.joined(separator: ",") + "\n"
                    }
                    
                    // Add division totals
                    let totals = divisionTotals
                    
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
        
        print("Package Progress - Total Apps: \(totalApps)")
        
        for (appName, appRecords) in groupedByApp {
            guard let firstRecord = appRecords.first else { continue }
            
            let packageStatus = firstRecord.applicationPackageStatus?.lowercased() ?? ""
            print("Package Progress - App: \(appName), Status: \(packageStatus)")
            
            if packageStatus == "ready" || packageStatus == "ready for testing" || packageStatus == "completed" || packageStatus == "passed" {
                totalPoints += 100.0
            } else if packageStatus == "in progress" {
                totalPoints += 50.0
            }
        }
        
        let progress = totalApps > 0 ? totalPoints / totalApps : 0.0
        print("Package Progress - Total Points: \(totalPoints), Final Progress: \(progress)%")
        return progress
    }
    
    private func calculateTestProgress(from groupedByApp: [String: [CombinedRecord]]) -> Double {
        var totalPoints = 0.0
        let totalApps = Double(groupedByApp.count)
        
        print("Test Progress - Total Apps: \(totalApps)")
        
        for (appName, appRecords) in groupedByApp {
            guard let firstRecord = appRecords.first else { continue }
            
            let testStatus = firstRecord.applicationTestStatus?.lowercased() ?? ""
            print("Test Progress - App: \(appName), Status: \(testStatus)")
            
            if testStatus == "ready" || testStatus == "completed" || testStatus == "passed" {
                totalPoints += 100.0
            } else if testStatus == "in progress" {
                totalPoints += 50.0
            }
        }
        
        let progress = totalApps > 0 ? totalPoints / totalApps : 0.0
        print("Test Progress - Total Points: \(totalPoints), Final Progress: \(progress)%")
        return progress
    }
    
    private func environmentBinding(for env: String) -> Binding<Bool> {
        Binding(
            get: {
                if env == "All" {
                    return selectedEnvironments.count == environments.count - 1
                }
                return selectedEnvironments.contains(env)
            },
            set: { isSelected in
                if env == "All" {
                    if isSelected {
                        selectedEnvironments = Set(environments.filter { $0 != "All" })
                    }
                } else {
                    if isSelected {
                        selectedEnvironments.insert(env)
                    } else if selectedEnvironments.count > 1 {
                        selectedEnvironments.remove(env)
                    }
                }
            }
        )
    }
}

#Preview {
    DivisionProgressView()
        .environmentObject(DatabaseManager.shared)
} 