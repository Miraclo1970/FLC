import SwiftUI
import GRDB

struct OrganisationSummary {
    let division: String
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

struct OrganisationProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
    // OTAP filter
    @State private var selectedOTAP: Set<String> = ["P"]
    
    // Additional filters
    @State private var excludeOutScope = true
    @State private var excludeWillBeAndSunset = true
    @State private var excludeNoHROrLeftUsers = true
    
    private var otapOptions: [String] {
        Array(Set(records.compactMap { $0.otap }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private func calculateOrganisationTotals(from departmentStats: [OrganisationSummary]) -> (applications: Int, users: Int, packageProgress: Double, testProgress: Double, overallProgress: Double, packageReadyDate: Date?, testReadyDate: Date?, migrationClusterReadiness: String) {
        // Get unique apps across all divisions
        let uniqueApps = Set(records.map { $0.applicationName }).count
        let totalUsers = departmentStats.reduce(0) { $0 + $1.users }
        
        // Calculate weighted averages based on number of applications
        var totalWeightedPackageProgress = 0.0
        var totalWeightedTestProgress = 0.0
        var totalWeight = 0
        
        // Calculate weighted readiness progress
        var totalWeightedReadiness = 0.0
        var readinessWeight = 0
        
        for stats in departmentStats {
            let weight = stats.applications
            totalWeightedPackageProgress += stats.packageProgress * Double(weight)
            totalWeightedTestProgress += stats.testProgress * Double(weight)
            totalWeight += weight
            
            // For readiness, calculate weighted progress
            if let readiness = stats.migrationClusterReadiness {
                totalWeightedReadiness += getMigrationClusterReadinessProgress(readiness) * Double(weight)
                readinessWeight += weight
            }
        }
        
        let avgPackageProgress = totalWeight > 0 ? totalWeightedPackageProgress / Double(totalWeight) : 0.0
        let avgTestProgress = totalWeight > 0 ? totalWeightedTestProgress / Double(totalWeight) : 0.0
        
        // First calculate the weighted average readiness
        let weightedReadinessProgress = readinessWeight > 0 ? totalWeightedReadiness / Double(readinessWeight) : 0.0
        // Then divide by total number of divisions to get fair representation
        let avgReadinessProgress = weightedReadinessProgress / Double(departmentStats.count)
        
        // Calculate preparation progress (average of package and test)
        let preparationProgress = (avgPackageProgress + avgTestProgress) / 2.0
        
        // Calculate overall progress as average of preparation and execution
        let overallProgress = (preparationProgress + avgReadinessProgress) / 2.0
        
        // Find latest dates
        let latestPackageDate = departmentStats.compactMap { $0.packageReadyDate }.max()
        let latestTestDate = departmentStats.compactMap { $0.testReadyDate }.max()
        
        return (
            applications: uniqueApps,
            users: totalUsers,
            packageProgress: avgPackageProgress,
            testProgress: avgTestProgress,
            overallProgress: overallProgress,
            packageReadyDate: latestPackageDate,
            testReadyDate: latestTestDate,
            migrationClusterReadiness: String(format: "%.1f%%", avgReadinessProgress)
        )
    }
    
    // Add helper functions for readiness calculations
    private func getMigrationClusterReadinessProgress(_ status: String?) -> Double {
        guard let status = status?.lowercased() else { return 0.0 }
        
        switch status {
        case "orderlist to dep":
            return 10.0
        case "orderlist confirmed":
            return 20.0
        case "waiting for apps":
            return 25.0
        case "on hold":
            return 30.0
        case "ready to start":
            return 50.0
        case "planned":
            return 60.0
        case "executed":
            return 90.0
        case "aftercare ok":
            return 98.0
        case "decharge":
            return 100.0
        default:
            return 0.0
        }
    }
    
    private func getReadinessStatusFromProgress(_ progress: Double) -> String {
        switch progress {
        case 0..<15:
            return "orderlist to dep"
        case 15..<22.5:
            return "orderlist confirmed"
        case 22.5..<27.5:
            return "waiting for apps"
        case 27.5..<40:
            return "on hold"
        case 40..<55:
            return "ready to start"
        case 55..<75:
            return "planned"
        case 75..<95:
            return "executed"
        case 95..<99:
            return "aftercare ok"
        case 99...100:
            return "decharge"
        default:
            return "orderlist to dep"
        }
    }
    
    private func getMigrationReadinessTextColor(_ status: String?) -> Color {
        guard let status = status?.lowercased() else { return .clear }
        switch status {
        case "orderlist to dep":
            return .blue.opacity(0.6)
        case "orderlist confirmed":
            return .blue.opacity(0.8)
        case "ready to start":
            return .blue
        case "waiting for apps":
            return .gray.opacity(0.8)
        case "on hold":
            return .orange.opacity(0.8)
        case "planned":
            return .green.opacity(0.6)
        case "executed":
            return .green.opacity(0.8)
        case "aftercare ok":
            return .green.opacity(0.9)
        case "decharge":
            return .green
        default:
            return .primary
        }
    }
    
    private func formatReadinessText(_ status: String?) -> String {
        guard let status = status else { return "-" }
        return status == "Decharge" ? "Decharge 🏁" : status
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Title
                Text("Organisation Progress")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                // OTAP Filter
                VStack(alignment: .leading, spacing: 10) {
                    Text("OTAP Filter")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 15) {
                        ForEach(otapOptions, id: \.self) { option in
                            Toggle(isOn: Binding(
                                get: { selectedOTAP.contains(option) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedOTAP.insert(option)
                                    } else {
                                        selectedOTAP.remove(option)
                                    }
                                    Task {
                                        await loadData()
                                    }
                                }
                            )) {
                                Text(option)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor)))
                
                // Additional Filters
                VStack(alignment: .leading, spacing: 10) {
                    Text("Additional Filters")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Toggle("Exclude out scope & out scope division", isOn: $excludeOutScope)
                        .onChange(of: excludeOutScope) { _, _ in
                            Task {
                                await loadData()
                            }
                        }
                    
                    Toggle("Exclude sunset and show only Will be app", isOn: $excludeWillBeAndSunset)
                        .onChange(of: excludeWillBeAndSunset) { _, _ in
                            Task {
                                await loadData()
                            }
                        }
                    
                    Toggle("Exclude users who have left", isOn: $excludeNoHROrLeftUsers)
                        .onChange(of: excludeNoHROrLeftUsers) { _, _ in
                            Task {
                                await loadData()
                            }
                        }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor)))
                
                ScrollView {
                    VStack(spacing: 8) {
                        // Header
                        HStack(spacing: 0) {
                            Text("Division")
                                .frame(width: 350, alignment: .leading)
                                .padding(.leading, 8)
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
                            Text("Application Readiness %")
                                .frame(width: 150, alignment: .center)
                            Text("Cluster Readiness %")
                                .frame(width: 100, alignment: .center)
                            Text("Overall Progress")
                                .frame(width: 100, alignment: .center)
                        }
                        .frame(width: 1200)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Organisation total row
                        organisationTotalRow
                        
                        // Division rows
                        ForEach(divisions, id: \.self) { division in
                            let divisionRecords = records.filter { $0.division == division }
                            let stats = calculateStats(for: divisionRecords)
                            let preparationProgress = (stats.packageProgress + stats.testProgress) / 2.0
                            let readinessProgress = getMigrationClusterReadinessProgress(stats.migrationClusterReadiness)
                            let overallProgress = (preparationProgress + readinessProgress) / 2.0
                            
                            HStack(spacing: 0) {
                                Text(division)
                                    .frame(width: 350, alignment: .leading)
                                    .padding(.leading, 8)
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
                                Text(String(format: "%.1f%%", preparationProgress))
                                    .frame(width: 150, alignment: .center)
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f%%", readinessProgress))
                                    .frame(width: 100, alignment: .center)
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f%%", overallProgress))
                                    .frame(width: 100, alignment: .center)
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 1200)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                        }
                    }
                }
                
                Spacer()
                
                // Export Bar
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Text("Export Organisation Progress Report")
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
                        .disabled(isExporting)
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
    
    private var organisationTotalRow: some View {
        let departmentStats = divisions.map { division in
            let divisionRecords = records.filter { $0.division == division }
            return calculateStats(for: divisionRecords)
        }
        
        let totals = calculateOrganisationTotals(from: departmentStats)
        
        return HStack(spacing: 0) {
            Text("Total Organisation")
                .bold()
                .frame(width: 350, alignment: .leading)
                .padding(.leading, 8)
            Text("\(totals.applications)")
                .bold()
                .frame(width: 60, alignment: .center)
            Text("\(totals.users)")
                .bold()
                .frame(width: 70, alignment: .center)
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
            Text(String(format: "%.1f%%", (totals.packageProgress + totals.testProgress) / 2.0))
                .bold()
                .frame(width: 150, alignment: .center)
                .foregroundColor(.blue)
            Text(totals.migrationClusterReadiness)
                .bold()
                .frame(width: 100, alignment: .center)
                .foregroundColor(.blue)
            Text(String(format: "%.1f%%", totals.overallProgress))
                .bold()
                .frame(width: 100, alignment: .center)
                .foregroundColor(.blue)
        }
        .frame(width: 1200)
        .padding(.vertical, 2)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    private func calculateStats(for records: [CombinedRecord]) -> OrganisationSummary {
        // Apply additional filters
        let filteredRecords = records.filter { record in
            // OTAP filter
            let otapMatch = selectedOTAP.contains(record.otap)
            
            // Out scope filter
            let outScopeMatch = !excludeOutScope || 
                (record.inScopeOutScopeDivision?.lowercased() != "out" &&
                 !(record.inScopeOutScopeDivision?.lowercased().starts(with: "out ") ?? false))
            
            // Will be and sunset filter
            let willBeMatch = !excludeWillBeAndSunset || {
                let willBe = record.willBe ?? ""
                return willBe.isEmpty || willBe == "N/A"
            }()
            
            // Left users filter
            let leftUserMatch = !excludeNoHROrLeftUsers ||
                (record.leaveDate == nil || record.leaveDate! > Date())
            
            return otapMatch && outScopeMatch && willBeMatch && leftUserMatch
        }

        let uniqueApps = Set(filteredRecords.map { $0.applicationName }).count
        let uniqueUsers = Set(filteredRecords.compactMap { $0.systemAccount }).count
        
        // Get migration cluster readiness from the first record
        let migrationClusterReadiness = filteredRecords.first?.migrationClusterReadiness
        
        // Group by application name
        let groupedByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
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
            switch testStatus {
            case "pat ok":
                totalTestPoints += 100.0
            case "pat on hold":
                totalTestPoints += 75.0
            case "pat planned":
                totalTestPoints += 60.0
            case "gat ok":
                totalTestPoints += 50.0
            case "in progress":
                totalTestPoints += 30.0
            case "", "not started":
                totalTestPoints += 0.0
            default:
                print("Unknown testing status: \(testStatus)")
                totalTestPoints += 0.0
            }
        }
        
        let packageProgress = totalApps > 0 ? totalPackagePoints / totalApps : 0.0
        let testProgress = totalApps > 0 ? totalTestPoints / totalApps : 0.0
        
        // Calculate preparation progress (average of package and test)
        let preparationProgress = (packageProgress + testProgress) / 2.0
        
        // Get execution progress from migration cluster readiness
        let executionProgress = getMigrationClusterReadinessProgress(migrationClusterReadiness)
        
        // Calculate combined progress as average of preparation and execution
        let combinedProgress = (preparationProgress + executionProgress) / 2.0
        
        let packageReadyDate = filteredRecords.compactMap { $0.applicationPackageReadinessDate }.max()
        let testReadyDate = filteredRecords.compactMap { $0.applicationTestReadinessDate }.max()
        
        return OrganisationSummary(
            division: filteredRecords.first?.division ?? "",
            applications: uniqueApps,
            users: uniqueUsers,
            packageProgress: packageProgress,
            testProgress: testProgress,
            packageReadyDate: packageReadyDate,
            testReadyDate: testReadyDate,
            combinedProgress: combinedProgress,
            status: determineStatus(progress: combinedProgress),
            migrationClusterReadiness: migrationClusterReadiness
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
                panel.nameFieldStringValue = "organisation_progress.csv"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = panel.url {
                    // Create CSV content
                    var csvContent = "Division,Applications,Users,Package Progress,Package Ready By,Testing Progress,Test Ready By,Overall Progress\n"
                    
                    // Add division rows
                    for division in divisions {
                        let divisionRecords = records.filter { $0.division == division }
                        let stats = calculateStats(for: divisionRecords)
                        
                        let fields = [
                            division,
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
                    
                    // Add organisation totals
                    let divisionStats = divisions.map { division in
                        let divisionRecords = records.filter { $0.division == division }
                        return calculateStats(for: divisionRecords)
                    }
                    
                    let totals = calculateOrganisationTotals(from: divisionStats)
                    
                    csvContent += "\nOrganisation Summary\n"
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
    OrganisationProgressView()
        .environmentObject(DatabaseManager.shared)
} 