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
}

struct OrganisationProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private func calculateOrganisationTotals(from divisionStats: [OrganisationSummary]) -> (applications: Int, users: Int, packageProgress: Double, testProgress: Double, overallProgress: Double, packageReadyDate: Date?, testReadyDate: Date?) {
        // Simple sum for applications and users
        let totalApplications = divisionStats.reduce(0) { $0 + $1.applications }
        let totalUsers = divisionStats.reduce(0) { $0 + $1.users }
        
        // Calculate weighted averages based on number of applications
        var totalWeightedPackageProgress = 0.0
        var totalWeightedTestProgress = 0.0
        var totalWeight = 0
        
        for stats in divisionStats {
            let weight = stats.applications
            totalWeightedPackageProgress += stats.packageProgress * Double(weight)
            totalWeightedTestProgress += stats.testProgress * Double(weight)
            totalWeight += weight
        }
        
        let avgPackageProgress = totalWeight > 0 ? totalWeightedPackageProgress / Double(totalWeight) : 0.0
        let avgTestProgress = totalWeight > 0 ? totalWeightedTestProgress / Double(totalWeight) : 0.0
        let overallProgress = (avgPackageProgress + avgTestProgress) / 2.0
        
        let latestPackageDate = divisionStats.compactMap { $0.packageReadyDate }.max()
        let latestTestDate = divisionStats.compactMap { $0.testReadyDate }.max()
        
        return (totalApplications, totalUsers, avgPackageProgress, avgTestProgress, overallProgress, latestPackageDate, latestTestDate)
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
                            Text("Progress")
                                .frame(width: 120, alignment: .center)
                        }
                        .frame(width: 970)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Organisation total row
                        let divisionStats = divisions.map { division in
                            let divisionRecords = records.filter { $0.division == division }
                            return calculateStats(for: divisionRecords)
                        }
                        
                        let totals = calculateOrganisationTotals(from: divisionStats)
                        
                        HStack(spacing: 0) {
                            Text("Total Organisation")
                                .bold()
                                .frame(width: 350, alignment: .leading)
                                .padding(.leading, 8)
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
                        .frame(width: 970)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        // Division rows
                        ForEach(divisions, id: \.self) { division in
                            let divisionRecords = records.filter { $0.division == division }
                            let stats = calculateStats(for: divisionRecords)
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
                                OverallProgressCell(progress: stats.combinedProgress)
                                    .frame(width: 120)
                            }
                            .frame(width: 970)
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
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    private func calculateStats(for records: [CombinedRecord]) -> OrganisationSummary {
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
        let combinedProgress = (packageProgress + testProgress) / 2.0
        
        let packageReadyDate = records.compactMap { $0.applicationPackageReadinessDate }.max()
        let testReadyDate = records.compactMap { $0.applicationTestReadinessDate }.max()
        
        let division = records.first?.division ?? ""
        
        return OrganisationSummary(
            division: division,
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