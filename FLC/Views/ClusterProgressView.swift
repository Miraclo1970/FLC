import SwiftUI
import GRDB

extension NSColor {
    static let lightBlue = NSColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1.0)
    static let mediumBlue = NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
    static let darkBlue = NSColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
    static let lightOrange = NSColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0)
    static let orange = NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
    static let lightGreen = NSColor(red: 0.8, green: 1.0, blue: 0.8, alpha: 1.0)
    static let green = NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0)
    static let darkGreen = NSColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0)
}

struct ClusterSummary {
    let cluster: String
    let migrationCluster: String
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
    
    private var textColor: Color {
        guard let value = readiness, !value.isEmpty else {
            return .primary
        }
        
        switch value.lowercased() {
        case "orderlist to dep", "orderlist confirmed", "ready to start":
            return .blue
        case "waiting for apps", "on hold":
            return .orange
        case "planned", "executed", "decharge", "aftercare ok":
            return .green
        default:
            return .primary
        }
    }
    
    var body: some View {
        Text(displayText)
            .frame(width: 150, alignment: .center)
            .foregroundColor(textColor)
    }
}

struct ClusterProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
    @AppStorage("clusterView.selectedCluster") private var selectedCluster: String = ""
    @AppStorage("clusterView.selectedDivision") private var selectedDivision: String = ""
    @AppStorage("clusterView.selectedEnvironments") private var selectedEnvironmentsString: String = "P"  // Default to Production
    @AppStorage("clusterView.excludeNonActive") private var excludeNonActive: Bool = false
    @AppStorage("clusterView.excludeLeftUsers") private var excludeLeftUsers: Bool = false
    @State private var selectedEnvironments: Set<String> = ["P"]  // Default to Production
    
    private let environments = ["A", "OT", "P", "Prullenbak", "TW", "VDI"]  // Updated environment options
    
    private func updateSelectedEnvironments() {
        selectedEnvironmentsString = selectedEnvironments.sorted().joined(separator: ",")
    }
    
    private func environmentBinding(for env: String) -> Binding<Bool> {
        Binding(
            get: {
                selectedEnvironments.contains(env)
            },
            set: { isSelected in
                if isSelected {
                    selectedEnvironments.insert(env)
                } else if selectedEnvironments.count > 1 {
                    selectedEnvironments.remove(env)
                }
                updateSelectedEnvironments()
            }
        )
    }
    
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
    
    private func shouldIncludeRecord(_ record: CombinedRecord) -> Bool {
        // Check cluster filter
        let matchesCluster = selectedCluster.isEmpty || 
                           selectedCluster == "All" || 
                           record.migrationCluster == selectedCluster
        
        // Check division filter
        let matchesDivision = selectedDivision.isEmpty || 
                            record.division == selectedDivision
        
        // Check environment filter
        let matchesEnvironment = !record.otap.isEmpty && selectedEnvironments.contains(record.otap)
        
        // Check out of scope and sunset filter
        let outScopeMatch = !excludeNonActive || 
            (record.inScopeOutScopeDivision?.lowercased() != "out" &&
             !(record.inScopeOutScopeDivision?.lowercased().starts(with: "out ") ?? false) &&
             (record.willBe?.isEmpty ?? true || record.willBe == "N/A"))
        
        // Check left users filter
        let leftUserMatch = !excludeLeftUsers || 
            (record.leaveDate == nil || record.leaveDate! > Date())
        
        return matchesCluster && matchesDivision && matchesEnvironment && outScopeMatch && leftUserMatch
    }
    
    private var filteredRecords: [CombinedRecord] {
        records.filter(shouldIncludeRecord)
    }
    
    private var departments: [String] {
        Array(Set(filteredRecords.compactMap { $0.departmentSimple }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    // Add new computed property for grouped records
    private var groupedByCluster: [(cluster: String, departments: [String])] {
        // First, group records by cluster
        let recordsByCluster = Dictionary(grouping: filteredRecords) { $0.migrationCluster ?? "Unknown" }
        
        // For each cluster, get its departments and sort them
        let clustersWithDepts = recordsByCluster.map { cluster, records in
            let clusterDepartments = Array(Set(records.compactMap { $0.departmentSimple }))
                .filter { !$0.isEmpty }
                .sorted()
            return (cluster: cluster, departments: clusterDepartments)
        }
        
        // Sort by cluster name
        return clustersWithDepts.sorted { $0.cluster < $1.cluster }
    }
    
    private func calculateClusterTotals(from departmentStats: [ClusterSummary]) -> (applications: Int, users: Int, packageProgress: Double, testProgress: Double, overallProgress: Double, packageReadyDate: Date?, testReadyDate: Date?, migrationClusterReadiness: String?) {
        // Get all records for the selected division/cluster
        let allRecords = filteredRecords
        
        // Count unique applications and users across all departments
        let uniqueApps = Set(allRecords.map { $0.applicationName }).count
        let uniqueUsers = Set(allRecords.compactMap { $0.systemAccount }).count
        
        // Calculate weighted progress based on number of applications
        var totalWeightedPackageProgress = 0.0
        var totalWeightedTestProgress = 0.0
        var totalWeightedReadinessProgress = 0.0
        var totalReadinessWeight = 0
        var totalWeight = 0
        var departmentsWithStatus = 0
        var totalDepartments = 0
        
        // Sum up weighted progress for all departments
        for stats in departmentStats {
            let weight = stats.applications
            if weight > 0 {
                totalWeightedPackageProgress += stats.packageProgress * Double(weight)
                totalWeightedTestProgress += stats.testProgress * Double(weight)
                totalWeight += weight
                totalDepartments += 1
                
                // Only include departments that have a valid readiness status and applications
                if let readinessProgress = getMigrationClusterReadinessProgress(stats.migrationClusterReadiness) {
                    totalWeightedReadinessProgress += readinessProgress * Double(weight)
                    totalReadinessWeight += weight
                    departmentsWithStatus += 1
                }
            }
        }
        
        // Calculate weighted averages
        let avgPackageProgress = totalWeight > 0 ? totalWeightedPackageProgress / Double(totalWeight) : 0.0
        let avgTestProgress = totalWeight > 0 ? totalWeightedTestProgress / Double(totalWeight) : 0.0
        
        // Calculate readiness progress only if we have enough departments with status (at least 50%)
        let minimumRequiredPercentage = 0.5 // 50%
        let hasEnoughDepartments = totalDepartments > 0 && 
            Double(departmentsWithStatus) / Double(totalDepartments) >= minimumRequiredPercentage
        
        let avgReadinessProgress = (totalReadinessWeight > 0 && hasEnoughDepartments) ? 
            totalWeightedReadinessProgress / Double(totalReadinessWeight) : 0.0
        
        // Convert average readiness progress back to status only if we have enough data
        let dominantStatus = hasEnoughDepartments ? getReadinessStatusFromProgress(avgReadinessProgress) : nil
        
        // Calculate combined progress
        let combinedProgress = (avgPackageProgress + avgTestProgress) / 2.0
        
        // Find latest dates
        let latestPackageDate = departmentStats.compactMap { $0.packageReadyDate }.max()
        let latestTestDate = departmentStats.compactMap { $0.testReadyDate }.max()
        
        return (
            applications: uniqueApps,
            users: uniqueUsers,
            packageProgress: avgPackageProgress,
            testProgress: avgTestProgress,
            overallProgress: combinedProgress,
            packageReadyDate: latestPackageDate,
            testReadyDate: latestTestDate,
            migrationClusterReadiness: dominantStatus
        )
    }
    
    // Helper function to convert progress back to status
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
    
    // MARK: - Sub-views
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cluster Progress")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Left column with existing filters
                VStack(alignment: .leading, spacing: 20) {
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
                
                // Middle column with environment filter
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
                
                // Right column with status filters
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
        .padding(.bottom, 8)
    }
    
    private var loadingView: some View {
        ProgressView("Loading data...")
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            filterSection
            
            if !selectedCluster.isEmpty {
                clusterDetailsView
            } else {
                Text("Please select a cluster")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            exportSection
        }
    }
    
    private var exportSection: some View {
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
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                loadingView
            } else {
                mainContent
            }
        }
        .padding()
        .task {
            await loadData()
        }
        .onAppear {
            selectedEnvironments = Set(selectedEnvironmentsString.split(separator: ",").map(String.init))
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
        
        // Get migration cluster from the first record
        let migrationCluster = records.first?.migrationCluster ?? ""
        
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
        
        // Calculate preparation progress (average of package and test)
        let preparationProgress = (packageProgress + testProgress) / 2.0
        
        // Get execution progress from migration cluster readiness
        let migrationClusterReadiness = records.first?.migrationClusterReadiness
        let executionProgress = getMigrationClusterReadinessProgress(migrationClusterReadiness) ?? 0.0
        
        // Calculate combined progress as average of preparation and execution
        let combinedProgress = (preparationProgress + executionProgress) / 2.0
        
        let packageReadyDate = records.compactMap { $0.applicationPackageReadinessDate }.max()
        let testReadyDate = records.compactMap { $0.applicationTestReadinessDate }.max()
        
        return ClusterSummary(
            cluster: selectedCluster,
            migrationCluster: migrationCluster,
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
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = selectedCluster == "All" ? "all_clusters_progress.csv" : "cluster_progress_\(selectedCluster).csv"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = panel.url {
                    // Create CSV content
                    var csvContent = "Migration Cluster,Department,Applications,Users,Package Progress,Package Ready By,Testing Progress,Test Ready By,Application Progress,Migration Cluster Readiness,Migration Cluster Readiness Progress\n"
                    
                    // Add department rows
                    for department in departments {
                        let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
                        let stats = calculateStats(for: departmentRecords)
                        
                        let readinessProgress = getMigrationClusterReadinessProgress(stats.migrationClusterReadiness) ?? 0.0
                        
                        let fields = [
                            selectedCluster,
                            department,
                            String(stats.applications),
                            String(stats.users),
                            String(format: "%.1f", stats.packageProgress),
                            stats.packageReadyDate.map { formatDate($0) } ?? "",
                            String(format: "%.1f", stats.testProgress),
                            stats.testReadyDate.map { formatDate($0) } ?? "",
                            String(format: "%.1f", stats.combinedProgress),
                            stats.migrationClusterReadiness ?? "",
                            String(format: "%.1f", readinessProgress)
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
    
    private func getMigrationClusterReadinessProgress(_ status: String?) -> Double? {
        guard let status = status?.lowercased(), !status.isEmpty else { return nil }
        
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
            return nil
        }
    }
    
    private func getMigrationClusterReadinessColor(_ status: String?) -> Color {
        guard let status = status?.lowercased() else { return .clear }
        
        switch status {
        case "orderlist to dep", "orderlist confirmed", "ready to start":
            return .blue
        case "waiting for apps", "on hold":
            return .orange
        case "planned", "executed", "decharge", "aftercare ok":
            return .green
        default:
            return .clear
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
        guard let status = status else { return "Not started" }
        return status == "Decharge" ? "Decharge 🏁" : status
    }
    
    private func progressCell(for stats: ClusterSummary, column: String) -> some View {
        let progress: Double
        let color: Color
        let showFinishFlag: Bool
        
        switch column {
        case "Package Progress":
            progress = stats.packageProgress
            color = .blue
            showFinishFlag = false
        case "Testing Progress":
            progress = stats.testProgress
            color = .blue
            showFinishFlag = false
        case "Migration Cluster Readiness":
            progress = getMigrationClusterReadinessProgress(stats.migrationClusterReadiness) ?? 0.0
            color = getMigrationClusterReadinessColor(stats.migrationClusterReadiness)
            showFinishFlag = stats.migrationClusterReadiness?.lowercased() == "decharge"
        default:
            progress = stats.combinedProgress
            color = .blue
            showFinishFlag = false
        }
        
        return HStack {
            ProgressBar(progress: progress, color: color)
                .frame(width: 100)
            if showFinishFlag {
                Image(systemName: "flag.fill")
                    .foregroundColor(.green)
            }
            Text(String(format: "%.1f%%", progress))
                .frame(width: 50, alignment: .trailing)
            if column == "Migration Cluster Readiness" {
                let displayStatus = getReadinessStatusFromProgress(progress)
                Text(displayStatus)
                    .frame(width: 120, alignment: .leading)
                    .foregroundColor(getMigrationReadinessTextColor(displayStatus))
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 0) {
            Text("Cluster")
                .frame(width: 150, alignment: .leading)
            Text("Department")
                .frame(width: 150, alignment: .leading)
            Text("Apps")
                .frame(width: 40, alignment: .center)
            Text("Users")
                .frame(width: 60, alignment: .center)
                .padding(.trailing, 20)
            VStack(spacing: 0) {
                Text("Average")
                Text("Package")
            }
            .frame(width: 120, alignment: .center)
            Text("Ready by")
                .frame(width: 60, alignment: .center)
            VStack(spacing: 0) {
                Text("Average")
                Text("Testing")
            }
            .frame(width: 120, alignment: .center)
            Text("Ready by")
                .frame(width: 60, alignment: .center)
            Text("Migration Cluster Readiness")
                .frame(width: 200, alignment: .center)
        }
        .frame(width: 980)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var clusterTotalRow: some View {
        let departmentStats = departments.map { department in
            let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
            return calculateStats(for: departmentRecords)
        }
        
        let totals = calculateClusterTotals(from: departmentStats)
        
        return HStack(spacing: 0) {
            Text("Total Cluster")
                .bold()
                .frame(width: 150, alignment: .leading)
            Text("")  // Empty Department for total
                .bold()
                .frame(width: 150, alignment: .leading)
            Text("\(totals.applications)")
                .bold()
                .frame(width: 40, alignment: .center)
            Text("\(totals.users)")
                .bold()
                .frame(width: 60, alignment: .center)
                .padding(.trailing, 20)
            AverageProgressCell(progress: totals.packageProgress)
                .frame(width: 120)
            Text(formatDate(totals.packageReadyDate))
                .bold()
                .frame(width: 60, alignment: .center)
                .font(.system(size: 11))
            AverageProgressCell(progress: totals.testProgress)
                .frame(width: 120)
            Text(formatDate(totals.testReadyDate))
                .bold()
                .frame(width: 60, alignment: .center)
                .font(.system(size: 11))
            if let readinessProgress = getMigrationClusterReadinessProgress(totals.migrationClusterReadiness) {
                Text(String(format: "%.1f%%", readinessProgress))
                    .bold()
                    .frame(width: 200, alignment: .center)
                    .foregroundColor(.blue)
            } else {
                Text("0.0%")
                    .bold()
                    .frame(width: 200, alignment: .center)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 980)
        .padding(.vertical, 2)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var departmentRows: some View {
        ForEach(groupedByCluster, id: \.cluster) { clusterGroup in
            ForEach(clusterGroup.departments, id: \.self) { department in
                DepartmentRow(
                    department: department,
                    filteredRecords: filteredRecords.filter { 
                        $0.migrationCluster == clusterGroup.cluster && 
                        $0.departmentSimple == department 
                    },
                    selectedCluster: selectedCluster,
                    calculateStats: calculateStats,
                    formatDate: formatDate,
                    getMigrationClusterReadinessProgress: getMigrationClusterReadinessProgress,
                    getMigrationClusterReadinessColor: getMigrationClusterReadinessColor,
                    getMigrationReadinessTextColor: getMigrationReadinessTextColor,
                    formatReadinessText: formatReadinessText
                )
            }
        }
    }
    
    private var clusterDetailsView: some View {
        ScrollView {
            VStack(spacing: 8) {
                headerView
                clusterTotalRow
                departmentRows
            }
            .padding(.leading, 4)  // Add small padding to the entire content
        }
    }
}

struct ProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                
                Rectangle()
                    .foregroundColor(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 100)) / 100)
            }
            .cornerRadius(4)
        }
    }
}

// MARK: - Supporting Views
struct DepartmentRow: View {
    let department: String
    let filteredRecords: [CombinedRecord]
    let selectedCluster: String
    let calculateStats: ([CombinedRecord]) -> ClusterSummary
    let formatDate: (Date?) -> String
    let getMigrationClusterReadinessProgress: (String?) -> Double?
    let getMigrationClusterReadinessColor: (String?) -> Color
    let getMigrationReadinessTextColor: (String?) -> Color
    let formatReadinessText: (String?) -> String
    
    var body: some View {
        let departmentRecords = filteredRecords.filter { $0.departmentSimple == department }
        let stats = calculateStats(departmentRecords)
        
        HStack(spacing: 0) {
            Text(stats.migrationCluster)
                .frame(width: 150, alignment: .leading)
            Text(department)
                .frame(width: 150, alignment: .leading)
            Text("\(stats.applications)")
                .frame(width: 40, alignment: .center)
            Text("\(stats.users)")
                .frame(width: 60, alignment: .center)
                .padding(.trailing, 20)
            AverageProgressCell(progress: stats.packageProgress)
                .frame(width: 120)
            Text(formatDate(stats.packageReadyDate))
                .frame(width: 60, alignment: .center)
                .font(.system(size: 11))
            AverageProgressCell(progress: stats.testProgress)
                .frame(width: 120)
            Text(formatDate(stats.testReadyDate))
                .frame(width: 60, alignment: .center)
                .font(.system(size: 11))
            if let readinessStatus = stats.migrationClusterReadiness {
                Text(formatReadinessText(readinessStatus))
                    .frame(width: 200, alignment: .center)
                    .foregroundColor(getMigrationReadinessTextColor(readinessStatus))
            } else {
                Text("Not started")
                    .frame(width: 200, alignment: .center)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 980)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ClusterProgressView()
        .environmentObject(DatabaseManager.shared)
} 
