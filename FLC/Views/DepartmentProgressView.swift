import SwiftUI
import GRDB

struct DepartmentProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @AppStorage("departmentView.selectedDivision") private var selectedDivision: String = ""
    @AppStorage("departmentView.selectedDepartment") private var selectedDepartment: String = ""
    @AppStorage("departmentView.excludeNonActive") private var excludeNonActive: Bool = false
    @AppStorage("departmentView.excludeLeftUsers") private var excludeLeftUsers: Bool = false
    @AppStorage("departmentView.sortColumn") private var sortColumnRaw: String = "name"
    @AppStorage("departmentView.sortAscending") private var sortAscending: Bool = true
    
    // Instead of using AppStorage for Sets (which isn't directly supported), we'll use State
    @State private var selectedEnvironments: Set<String> = ["P"]
    @State private var selectedPlatforms: Set<String> = ["All"]
    
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var exportError: String?
    
    private var sortColumn: SortColumn {
        get {
            SortColumn(rawValue: sortColumnRaw) ?? .name
        }
        set {
            sortColumnRaw = newValue.rawValue
        }
    }
    
    private enum SortColumn: String {
        case name, users, departments, packageStatus, testResult
    }
    
    private let environments = ["All", "P", "A", "OT"]
    private let platforms = ["All", "SAAS", "VDI", "Local"]
    
    // Available divisions and departments
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var departments: [String] {
        Array(Set(records.filter { record in
            selectedDivision == "All" || record.division == selectedDivision
        }
        .compactMap { $0.departmentSimple }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    // MARK: - Sub-views
    private var loadingView: some View {
        ProgressView("Loading data...")
    }
    
    private var divisionPicker: some View {
        VStack(alignment: .leading) {
            Text("Division:")
                .font(.subheadline)
            Picker("", selection: $selectedDivision) {
                Text("Select Division").tag("")
                Text("All Divisions").tag("All")
                ForEach(divisions, id: \.self) { division in
                    Text(division).tag(division)
                }
            }
            .frame(width: 200)
        }
    }
    
    private var departmentPicker: some View {
        VStack(alignment: .leading) {
            Text("Department Simple:")
                .font(.subheadline)
            Picker("", selection: $selectedDepartment) {
                Text("Select Department Simple").tag("")
                Text("All Departments").tag("All")
                ForEach(departments, id: \.self) { department in
                    Text(department).tag(department)
                }
            }
            .frame(width: 200)
            .disabled(selectedDivision.isEmpty)
        }
    }
    
    private var environmentFilter: some View {
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
    
    private var statusFilter: some View {
        VStack(alignment: .leading) {
            Text("Status:")
                .font(.subheadline)
            Toggle("Exclude Sunset & Out of scope", isOn: $excludeNonActive)
                .toggleStyle(.checkbox)
            Toggle("Exclude users who have left", isOn: $excludeLeftUsers)
                .toggleStyle(.checkbox)
        }
    }
    
    private var platformFilter: some View {
        VStack(alignment: .leading) {
            Text("Platform:")
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(platforms, id: \.self) { platform in
                    Toggle(platform, isOn: platformBinding(for: platform))
                        .toggleStyle(.checkbox)
                }
            }
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Department Simple")
                .font(.headline)
            
            HStack(spacing: 20) {
                divisionPicker
                departmentPicker
                Spacer()
                environmentFilter
                statusFilter
                platformFilter
            }
        }
        .frame(width: 1090)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
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
    
    private func platformBinding(for platform: String) -> Binding<Bool> {
        Binding(
            get: { selectedPlatforms.contains(platform) },
            set: { isSelected in
                if platform == "All" {
                    if isSelected {
                        selectedPlatforms = ["All"]
                    } else {
                        selectedPlatforms = ["SAAS"]
                    }
                } else {
                    if isSelected {
                        selectedPlatforms.remove("All")
                        selectedPlatforms.insert(platform)
                    } else if selectedPlatforms.count > 1 {
                        selectedPlatforms.remove(platform)
                    }
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                loadingView
            } else {
                filtersSection
                resultsView
                exportSection
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            records = try await databaseManager.fetchCombinedRecords()
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    private func getProgressBarColor(for status: String, isTestStatus: Bool = false) -> Color {
        if isTestStatus {
            switch status.lowercased() {
            case "pat ok":
                return .green
            case "pat on hold":
                return .red
            case "pat planned":
                return .green.opacity(0.6)  // Light green
            case "gat ok":
                return .blue  // Middle blue
            case "in progress":
                return .blue.opacity(0.6)  // Light blue
            default:
                return .gray
            }
        }
        // For non-test status, use default blue
        return .blue
    }
    
    private struct ApplicationInfo: Identifiable {
        let id = UUID()
        let name: String
        let willBe: String
        let platform: String
        let inOutScope: String
        let uniqueUsers: Int
        let uniqueDepartments: Int
        let packageStatus: String
        let packageReadinessDate: Date?
        let testingStatus: String
        let testReadinessDate: Date?
        let testResult: String
        var applicationReadiness: String {
            if !willBe.isEmpty && willBe != "N/A" {
                return "Sunset"  // Say goodbye to an application
            }
            if inOutScope.lowercased() == "out" {
                return "Out of scope"      // Will be shown as blue cross
            }
            
            // Calculate combined progress
            let packagePoints = {
                switch packageStatus.lowercased() {
                case "ready", "ready for testing", "completed", "passed":
                    return 100.0
                case "in progress":
                    return 50.0
                default:
                    return 0.0
                }
            }()
            
            let testingPoints = {
                switch testingStatus.lowercased() {
                case "pat ok":
                    return 100.0
                case "pat on hold":
                    return 75.0
                case "pat planned":
                    return 60.0
                case "gat ok":
                    return 50.0
                case "in progress":
                    return 30.0
                case "", "not started":
                    return 0.0
                default:
                    print("Unknown testing status: \(testingStatus)")
                    return 0.0
                }
            }()
            
            let combinedProgress = (packagePoints + testingPoints) / 2
            
            switch combinedProgress {
            case 0:
                return "Not Started"
            case 100:
                return "Migration ready"
            default:
                return "In Progress"
            }
        }
    }
    
    private var departmentApplications: [ApplicationInfo] {
        // First, filter records by division and OTAP only (for department counting)
        let divisionRecords = records.filter { record in
            (selectedDivision == "All" || record.division == selectedDivision) &&
            (selectedEnvironments.contains("All") || selectedEnvironments.contains(record.otap))
        }
        
        // Then filter for display based on selected department and user filters
        let filteredRecords = records.filter { record in
            // Basic filters
            let basicFilter = (selectedDivision == "All" || record.division == selectedDivision) &&
            (selectedDepartment == "All" || selectedDepartment == "" || record.departmentSimple == selectedDepartment) &&
            (selectedEnvironments.contains("All") || selectedEnvironments.contains(record.otap))
            
            // Leave date filter - only include users who haven't left
            let leaveFilter = !excludeLeftUsers || (record.leaveDate == nil || record.leaveDate! > Date())
            
            // Out of scope filter
            let inOutScope = (record.inScopeOutScopeDivision ?? "").lowercased()
            let isOutOfScope = excludeNonActive && (inOutScope == "out" || inOutScope.hasPrefix("out "))
            
            // Will be filter - exclude applications that will be migrated to another application
            let willBe = record.willBe ?? ""
            let willBeFilter = !excludeNonActive || willBe.isEmpty || willBe == "N/A"
            
            return basicFilter && leaveFilter && !isOutOfScope && willBeFilter
        }
        
        // Group all division records by application name for department counting
        let divisionGroupedByApp = Dictionary(grouping: divisionRecords) { $0.applicationName }
        
        // Group filtered records by application name for display
        var groupedByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
        // Create a set of all "Will be" targets
        let willBeTargets = Set(records.compactMap { $0.willBe }
            .filter { !$0.isEmpty && $0 != "N/A" })
        
        // If we're excluding non-active apps, add the "will be" target applications
        if excludeNonActive {
            // First, create a mapping of old apps to their target apps
            var willBeMapping: [String: String] = [:]
            for record in records {
                if let willBe = record.willBe, !willBe.isEmpty, willBe != "N/A" {
                    willBeMapping[record.applicationName] = willBe
                }
            }
            
            // Group old applications by their target "will be" application
            var willBeGroups: [String: [String]] = [:]
            for (oldApp, willBeApp) in willBeMapping {
                willBeGroups[willBeApp, default: []].append(oldApp)
            }
            
            print("\nWill Be Migration Summary:")
            for (willBeApp, oldApps) in willBeGroups {
                print("\nTarget Application: \(willBeApp)")
                print("Source Applications: \(oldApps.joined(separator: ", "))")
                
                // Get or create target app records
                var targetRecords = groupedByApp[willBeApp] ?? []
                let originalTargetUsers = Set(targetRecords.map { $0.systemAccount })
                print("Target app original user count: \(originalTargetUsers.count)")
                
                // Collect all users from old applications
                var allMigratedUsers = Set<String>()
                for oldApp in oldApps {
                    if let oldAppRecords = groupedByApp[oldApp] {
                        let oldAppUsers = Set(oldAppRecords.map { $0.systemAccount })
                        print("- From \(oldApp):")
                        print("  • Original users: \(oldAppUsers.count)")
                        
                        // Add users to the combined set
                        allMigratedUsers.formUnion(oldAppUsers)
                        
                        // Remove the old application
                        groupedByApp.removeValue(forKey: oldApp)
                    }
                }
                
                // Calculate new users (excluding those already in target)
                let newUsers = allMigratedUsers.subtracting(originalTargetUsers)
                print("New unique users to add: \(newUsers.count)")
                
                // Add records for new users to target application
                if !newUsers.isEmpty {
                    let recordsToAdd = records.filter { record in
                        newUsers.contains(record.systemAccount) &&
                        oldApps.contains(record.applicationName) &&
                        (selectedDivision == "All" || record.division == selectedDivision) &&
                        (selectedDepartment == "All" || selectedDepartment == "" || record.departmentSimple == selectedDepartment)
                    }
                    targetRecords.append(contentsOf: recordsToAdd)
                    groupedByApp[willBeApp] = targetRecords
                }
                
                let finalUserCount = Set(groupedByApp[willBeApp]?.map { $0.systemAccount } ?? []).count
                print("Final target app user count: \(finalUserCount)")
                print("Total unique users added: \(newUsers.count)")
            }
        }
        
        // Convert to ApplicationInfo array
        var applications = groupedByApp.map { appName, appRecords in
            let uniqueUsers = Set(appRecords.map { $0.systemAccount }).count
            
            // Count unique departments from division records for this application
            let uniqueDepartments = Set(divisionGroupedByApp[appName]?.compactMap { record in
                record.departmentSimple
            } ?? []).count
            
            let firstRecord = appRecords.first
            
            // If this app is a "Will be" target, use its platform info
            let platform: String
            if willBeTargets.contains(appName) {
                // Find records where this app is the target
                let targetRecords = records.filter { record in 
                    guard let willBe = record.willBe else { return false }
                    return willBe == appName 
                }
                if let targetRecord = targetRecords.first {
                    platform = targetRecord.migrationPlatform ?? "N/A"
                } else {
                    platform = firstRecord?.migrationPlatform ?? "N/A"
                }
            } else {
                platform = firstRecord?.migrationPlatform ?? "N/A"
            }
            
            return ApplicationInfo(
                name: appName,
                willBe: firstRecord?.willBe ?? "",
                platform: platform,
                inOutScope: firstRecord?.inScopeOutScopeDivision ?? "N/A",
                uniqueUsers: uniqueUsers,
                uniqueDepartments: uniqueDepartments,
                packageStatus: firstRecord?.applicationPackageStatus ?? "Not Started",
                packageReadinessDate: firstRecord?.applicationPackageReadinessDate,
                testingStatus: firstRecord?.applicationTestStatus ?? "Not Started",
                testReadinessDate: firstRecord?.applicationTestReadinessDate,
                testResult: firstRecord?.testResult ?? ""
            )
        }
        
        // Apply platform filter
        applications = applications.filter { app in
            selectedPlatforms.contains("All") || selectedPlatforms.contains(app.platform)
        }
        
        // Apply sorting
        return getSortedApplications(applications)
    }
    
    private var totalUniqueUsers: Int {
        let filteredRecords = records.filter { record in
            // Basic filters
            let basicFilter = (selectedDivision == "All" || record.division == selectedDivision) &&
            (selectedDepartment == "All" || selectedDepartment == "" || record.departmentSimple == selectedDepartment) &&
            (selectedEnvironments.contains("All") || selectedEnvironments.contains(record.otap))
            
            // Leave date filter - only include users who haven't left
            let leaveFilter = !excludeLeftUsers || (record.leaveDate == nil || record.leaveDate! > Date())
            
            // Out of scope filter
            let inOutScope = (record.inScopeOutScopeDivision ?? "").lowercased()
            let isOutOfScope = excludeNonActive && (inOutScope == "out" || inOutScope.hasPrefix("out "))
            
            return basicFilter && leaveFilter && !isOutOfScope
        }
        return Set(filteredRecords.map { $0.systemAccount }).count
    }
    
    private var totalUniqueDepartments: Int {
        let filteredRecords = records.filter { record in
            // Basic filters
            let basicFilter = (selectedDivision == "All" || record.division == selectedDivision) &&
            (selectedDepartment == "All" || selectedDepartment == "" || record.departmentSimple == selectedDepartment) &&
            (selectedEnvironments.contains("All") || selectedEnvironments.contains(record.otap))
            
            // Out of scope filter
            let inOutScope = (record.inScopeOutScopeDivision ?? "").lowercased()
            let isOutOfScope = excludeNonActive && (inOutScope == "out" || inOutScope.hasPrefix("out "))
            
            return basicFilter && !isOutOfScope
        }
        return Set(filteredRecords.compactMap { $0.departmentSimple }).count
    }
    
    private var averagePackageProgress: String {
        print("Calculating Package Progress:")
        departmentApplications.forEach { app in
            print("App: \(app.name), Status: \(app.packageStatus)")
        }
        
        let total = departmentApplications.reduce(0.0) { sum, app in
            let status = app.packageStatus.lowercased()
            let points = {
                if status == "ready" || status == "ready for testing" {
                    return 100.0
                } else if status == "in progress" {
                    return 50.0
                } else if status == "not started" || status.isEmpty {
                    return 0.0
                } else {
                    print("Unknown status: \(status)")
                    return 0.0
                }
            }()
            print("Adding points for \(app.name): \(points) (status: \(app.packageStatus))")
            return sum + points
        }
        let average = departmentApplications.isEmpty ? 0.0 : total / Double(departmentApplications.count)
        print("Total points: \(total), Count: \(departmentApplications.count), Average: \(average)")
        return String(format: "%.0f", average)
    }
    
    private var averageTestingProgress: String {
        print("Calculating Testing Progress:")
        departmentApplications.forEach { app in
            print("App: \(app.name), Status: \(app.testingStatus)")
        }
        
        let total = departmentApplications.reduce(0.0) { sum, app in
            let status = app.testingStatus.lowercased()
            let points = {
                switch status {
                case "pat ok":
                    return 100.0
                case "pat on hold":
                    return 75.0
                case "pat planned":
                    return 60.0
                case "gat ok":
                    return 50.0
                case "in progress":
                    return 30.0
                case "not started", "":
                    return 0.0
                default:
                    print("Unknown testing status: \(status)")
                    return 0.0
                }
            }()
            print("Adding points for \(app.name): \(points) (status: \(app.testingStatus))")
            return sum + points
        }
        let average = departmentApplications.isEmpty ? 0.0 : total / Double(departmentApplications.count)
        print("Total points: \(total), Count: \(departmentApplications.count), Average: \(average)")
        return String(format: "%.0f", average)
    }
    
    private var averageMigrationProgress: String {
        let total = departmentApplications.reduce(0.0) { sum, app in
            sum + (app.applicationReadiness == "Migration ready" ? 100.0 :
                  app.applicationReadiness == "In Progress" ? 50.0 : 0.0)
        }
        let average = departmentApplications.isEmpty ? 0.0 : total / Double(departmentApplications.count)
        return String(format: "%.0f", average)
    }
    
    private var latestReadinessDate: Date? {
        departmentApplications
            .compactMap { $0.packageReadinessDate }
            .max()
    }
    
    private var latestTestReadinessDate: Date? {
        departmentApplications
            .compactMap { $0.testReadinessDate }
            .max()
    }
    
    private func exportAsCSV() {
        isExporting = true
        exportError = nil
        
        Task {
            do {
                // Get save location from user
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = "department_progress_\(selectedDivision)_\(selectedDepartment == "All" ? "all" : selectedDepartment).csv"
                
                guard let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
                    throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find window for save panel"])
                }
                
                let response = await panel.beginSheetModal(for: window)
                
                if response == .OK, let url = panel.url {
                    // Create CSV content
                    var csvContent = "Application Name,Will Be,Platform,In/Out Scope,Users,Package Status,Package Ready By,Testing Status,Test Ready By,Application Readiness\n"
                    
                    for app in departmentApplications {
                        let fields = [
                            app.name,
                            app.willBe,
                            app.platform,
                            app.inOutScope,
                            String(app.uniqueUsers),
                            app.packageStatus,
                            app.packageReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-",
                            app.testingStatus,
                            app.testReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-",
                            app.applicationReadiness
                        ].map { field in
                            // Properly escape fields that contain commas, quotes, or newlines
                            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                                .replacingOccurrences(of: "\n", with: " ")
                                .replacingOccurrences(of: "\r", with: " ")
                            return "\"\(escaped)\""
                        }
                        
                        csvContent += fields.joined(separator: ",") + "\n"
                    }
                    
                    // Add summary row with safe value handling
                    csvContent += "\nSummary\n"
                    csvContent += "Total Applications,\(departmentApplications.count)\n"
                    csvContent += "Total Users,\(totalUniqueUsers)\n"
                    csvContent += "Average Package Progress,\(averagePackageProgress)%\n"
                    csvContent += "Average Testing Progress,\(averageTestingProgress)%\n"
                    csvContent += "Latest Package Ready Date,\(latestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")\n"
                    csvContent += "Latest Test Ready Date,\(latestTestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")\n"
                    
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
    
    private func formatDateWithColor(_ testDate: Date?, packageDate: Date?) -> Text {
        let dateStr = testDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-"
        return Text(dateStr)
            .foregroundColor(testDate != nil && packageDate != nil && testDate! < packageDate! ? .red : .primary)
    }
    
    private func getSortedApplications(_ apps: [ApplicationInfo]) -> [ApplicationInfo] {
        apps.sorted { first, second in
            let result: Bool
            switch SortColumn(rawValue: sortColumnRaw) ?? .name {
            case .name:
                result = first.name.localizedCompare(second.name) == .orderedAscending
            case .users:
                result = first.uniqueUsers < second.uniqueUsers
            case .departments:
                result = first.uniqueDepartments < second.uniqueDepartments
            case .packageStatus:
                result = first.packageStatus.localizedCompare(second.packageStatus) == .orderedAscending
            case .testResult:
                result = first.testResult.localizedCompare(second.testResult) == .orderedAscending
            }
            return sortAscending ? result : !result
        }
    }
    
    private func SortableColumnHeader(_ title: String, column: SortColumn, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Button(action: {
            if sortColumnRaw == column.rawValue {
                sortAscending.toggle()
            } else {
                sortColumnRaw = column.rawValue
                sortAscending = true
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                if sortColumnRaw == column.rawValue {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }
    
    private func getBestTestResult(from apps: [ApplicationInfo]) -> String {
        let testResults = apps.compactMap { $0.testResult }
        if testResults.isEmpty {
            return "-"
        } else {
            let bestResult = testResults.max { $0.localizedCompare($1) == .orderedAscending }
            return bestResult ?? "-"
        }
    }
    
    private func getTestResultColor(_ testResult: String) -> Color {
        switch testResult.lowercased() {
        case "gat ok":
            return .green
        case "fat ok":
            return Color(red: 0.4, green: 0.8, blue: 0.4) // light green
        case "fat nok", "gat nok":
            return .orange
        case "on hold", "reject":
            return .red
        case "not started", "":
            return .gray
        default:
            return .primary
        }
    }
    
    private var resultsHeader: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text("\(selectedDivision)")
                    .font(.headline)
                Text("\(selectedDepartment)")
                    .font(.headline)
            }
            .frame(width: 300, alignment: .leading)
            .padding(.leading, 8)
            Text("")
                .frame(width: 100, alignment: .leading)
            Text("")
                .frame(width: 80, alignment: .leading)
            Text("")
                .frame(width: 80, alignment: .leading)
            Text("Users")
                .frame(width: 60, alignment: .center)
            Text("Depts")
                .frame(width: 60, alignment: .center)
            VStack {
                Text("Average")
                Text("Package")
            }
            .frame(width: 120, alignment: .center)
            Text("Ready by")
                .frame(width: 80, alignment: .center)
            VStack {
                Text("Average")
                Text("Testing")
            }
            .frame(width: 120, alignment: .center)
            Text("Ready by")
                .frame(width: 80, alignment: .center)
            Text("Test\nResult")
                .frame(width: 80, alignment: .center)
                .multilineTextAlignment(.center)
            Text("Application\nReadiness")
                .frame(width: 120, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .frame(width: 1280)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var resultsValues: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text("\(selectedDivision)")
                    .font(.headline)
                Text("\(selectedDepartment)")
                    .font(.headline)
            }
            .frame(width: 300, alignment: .leading)
            .padding(.leading, 8)
            Text("")
                .frame(width: 100, alignment: .leading)
            Text("")
                .frame(width: 80, alignment: .leading)
            
            // Application count
            Text("\(departmentApplications.count) App\(departmentApplications.count == 1 ? "" : "s")")
                .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.4))  // Soft yellow
                .frame(width: 80, alignment: .leading)
            
            Text("\(totalUniqueUsers)")
                .frame(width: 60, alignment: .center)
            Text("\(totalUniqueDepartments)")
                .frame(width: 60, alignment: .center)
            AverageProgressCell(progress: Double(averagePackageProgress) ?? 0)
                .frame(width: 120)
            Text(latestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                .frame(width: 80, alignment: .center)
                .font(.system(size: 11))
            AverageProgressCell(progress: Double(averageTestingProgress) ?? 0)
                .frame(width: 120)
            Text(latestTestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                .frame(width: 80, alignment: .center)
                .font(.system(size: 11))
            Text(getBestTestResult(from: departmentApplications))
                .frame(width: 80, alignment: .center)
                .foregroundColor(getTestResultColor(getBestTestResult(from: departmentApplications)))
            Text("\(Int(Double(averageMigrationProgress) ?? 0))%")
                .frame(width: 120, alignment: .center)
        }
        .frame(width: 1280)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var applicationsListHeader: some View {
        HStack(spacing: 0) {
            SortableColumnHeader("Application", column: .name, width: 300)
                .padding(.leading, 8)
            Text("Will be")
                .frame(width: 100, alignment: .leading)
            Text("Platform")
                .frame(width: 80, alignment: .leading)
            Text("In/Out Scope")
                .frame(width: 80, alignment: .leading)
            SortableColumnHeader("Users", column: .users, width: 60, alignment: .center)
            SortableColumnHeader("Depts", column: .departments, width: 60, alignment: .center)
            VStack {
                Text("Average")
                Text("Package")
            }
            .frame(width: 120, alignment: .center)
            Text("Ready by")
                .frame(width: 80, alignment: .center)
            VStack {
                Text("Average")
                Text("Testing")
            }
            .frame(width: 120, alignment: .center)
            Text("Ready by")
                .frame(width: 80, alignment: .center)
            SortableColumnHeader("Test\nResult", column: .testResult, width: 80, alignment: .center)
                .multilineTextAlignment(.center)
            Text("Application\nReadiness")
                .frame(width: 120, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .font(.headline)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var applicationsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            applicationsListHeader
            
            ForEach(departmentApplications, id: \.name) { app in
                ApplicationRow(app: app)
            }
        }
        .frame(width: 1280)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var exportSection: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Text("Export Progress Report")
                    .font(.headline)
                
                Spacer()
                
                if let error = exportError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: exportAsCSV) {
                    HStack(spacing: 8) {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 20, height: 20)
                                .fixedSize()
                        } else {
                            Image(systemName: "arrow.down.doc")
                        }
                        Text("Export to CSV")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || departmentApplications.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                resultsHeader
                resultsValues
                applicationsList
            }
        }
    }
    
    private struct ApplicationRow: View {
        private let app: ApplicationInfo
        
        fileprivate init(app: ApplicationInfo) {
            self.app = app
        }
        
        var body: some View {
            HStack(spacing: 0) {
                Text(app.name)
                    .frame(width: 300, alignment: .leading)
                    .lineLimit(1)
                    .padding(.leading, 8)
                Text(app.willBe)
                    .frame(width: 100, alignment: .leading)
                Text(app.platform == "N/A" ? "" : app.platform)
                    .frame(width: 80, alignment: .leading)
                Text(app.inOutScope == "N/A" ? "" : app.inOutScope)
                    .frame(width: 80, alignment: .leading)
                Text("\(app.uniqueUsers)")
                    .frame(width: 60, alignment: .center)
                Text("\(app.uniqueDepartments)")
                    .frame(width: 60, alignment: .center)
                DepartmentProgressCell(status: app.packageStatus)
                    .frame(width: 120)
                Text(app.packageReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                    .frame(width: 80, alignment: .center)
                    .font(.system(size: 11))
                DepartmentProgressCell(status: app.testingStatus)
                    .frame(width: 120)
                self.formatDateWithColor(app.testReadinessDate, packageDate: app.packageReadinessDate)
                    .frame(width: 80, alignment: .center)
                    .font(.system(size: 11))
                Text(app.testResult)
                    .frame(width: 80, alignment: .center)
                    .foregroundColor(getTestResultColor(app.testResult))
                Text(app.applicationReadiness)
                    .frame(width: 120)
                    .foregroundColor(getApplicationReadinessColor(app.applicationReadiness))
            }
            .padding(.vertical, 4)
        }
        
        private func formatDateWithColor(_ testDate: Date?, packageDate: Date?) -> Text {
            let dateStr = testDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-"
            return Text(dateStr)
                .foregroundColor(testDate != nil && packageDate != nil && testDate! < packageDate! ? .red : .primary)
        }
        
        private func getTestResultColor(_ testResult: String) -> Color {
            switch testResult.lowercased() {
            case "gat ok":
                return .green
            case "fat ok":
                return Color(red: 0.4, green: 0.8, blue: 0.4) // light green
            case "fat nok", "gat nok":
                return .orange
            case "on hold", "reject":
                return .red
            case "not started", "":
                return .gray
            default:
                return .primary
            }
        }
        
        private func getApplicationReadinessColor(_ readiness: String) -> Color {
            switch readiness {
            case "Sunset":
                return .orange
            case "Out of scope":
                return .cyan
            case "Migration ready":
                return .green
            case "In Progress":
                return .blue
            default:
                return .gray
            }
        }
    }
}

extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()
}

#Preview {
    DepartmentProgressView()
        .environmentObject(DatabaseManager.shared)
} 