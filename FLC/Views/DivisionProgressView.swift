import SwiftUI
import GRDB

struct DivisionProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var selectedDivision: String = ""
    @State private var selectedEnvironments: Set<String> = ["P"]  // Default to P selected
    @State private var excludeStatusFilter = false
    @State private var selectedPlatforms: Set<String> = ["All"]  // Default to All selected
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    
    private let platforms = ["All", "SAAS", "VDI", "Local"]
    private let environments = ["P", "A", "T"]
    
    // Available divisions
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var filteredRecords: [CombinedRecord] {
        records.filter { record in
            // Apply division filter
            let matchesDivision = selectedDivision.isEmpty || record.division == selectedDivision
            
            // Apply environment filter
            let matchesEnvironment = selectedEnvironments.contains(record.otap)
            
            // Apply platform filter if any platforms are selected
            let passesPlatformFilter = selectedPlatforms.contains("All") || 
                (record.migrationPlatform != nil && record.migrationPlatform != "N/A" && selectedPlatforms.contains(record.migrationPlatform ?? ""))
            
            return matchesDivision && matchesEnvironment && passesPlatformFilter
        }
    }
    
    private var departmentProgress: [(department: String, stats: DivisionStats)] {
        // First filter out Sunset and Out of scope applications if filter is enabled
        let activeRecords = filteredRecords.filter { record in
            !excludeStatusFilter || 
            ((record.willBe?.isEmpty ?? true || record.willBe == "N/A") && 
             (record.inScopeOutScopeDivision?.lowercased() != "out"))
        }
        
        let groupedByDepartment = Dictionary(grouping: activeRecords) { $0.departmentSimple ?? "Unknown" }
        
        return groupedByDepartment.map { department, records in
            // Count unique applications
            let uniqueApplications = Set(records.map { $0.applicationName }).count
            let totalUsers = Set(records.compactMap { $0.systemAccount }).count
            
            // Calculate progress based on unique applications
            let uniqueApps = Array(Set(records.map { $0.applicationName }))
            let packageProgress = uniqueApps.reduce(0.0) { sum, appName in
                let appRecords = records.filter { $0.applicationName == appName }
                if let record = appRecords.first {
                    let status = record.applicationPackageStatus?.lowercased() ?? ""
                    if status == "n/a" {
                        return sum + 0.0  // Treat N/A as Not Started
                    }
                    if status == "ready for testing" {
                        return sum + 100.0
                    }
                    switch status {
                    case "ready", "completed", "passed":
                        return sum + 100.0
                    case "in progress":
                        return sum + 50.0
                    case "not started", "":
                        return sum + 0.0
                    default:
                        print("Unknown package status: \(status)")
                        return sum + 0.0
                    }
                }
                return sum
            } / Double(uniqueApplications)
            
            let testingProgress = uniqueApps.reduce(0.0) { sum, appName in
                let appRecords = records.filter { $0.applicationName == appName }
                if let record = appRecords.first {
                    let status = record.applicationTestStatus?.lowercased() ?? ""
                    if status == "n/a" {
                        return sum + 0.0  // Treat N/A as Not Started
                    }
                    switch status {
                    case "ready", "completed", "passed":
                        return sum + 100.0
                    case "in progress":
                        return sum + 50.0
                    case "not started", "":
                        return sum + 0.0
                    default:
                        print("Unknown testing status: \(status)")
                        return sum + 0.0
                    }
                }
                return sum
            } / Double(uniqueApplications)
            
            let latestReadinessDate = records.compactMap { $0.applicationPackageReadinessDate }.max()
            let latestTestReadinessDate = records.compactMap { $0.applicationTestReadinessDate }.max()
            
            return (
                department: department,
                stats: DivisionStats(
                    totalApplications: uniqueApplications,
                    totalUsers: totalUsers,
                    averagePackageProgress: packageProgress,
                    averageTestingProgress: testingProgress,
                    latestReadinessDate: latestReadinessDate,
                    latestTestReadinessDate: latestTestReadinessDate
                )
            )
        }.sorted { $0.department < $1.department }
    }
    
    private var divisionTotals: DivisionStats {
        let totalApplications = Set(departmentProgress.flatMap { dept in
            filteredRecords.filter { $0.departmentSimple == dept.department }
                .map { $0.applicationName }
        }).count
        
        let totalUsers = Set(departmentProgress.flatMap { dept in
            filteredRecords.filter { $0.departmentSimple == dept.department }
                .compactMap { $0.systemAccount }
        }).count
        
        let averagePackageProgress = departmentProgress.reduce(0.0) { sum, dept in
            sum + (dept.stats.averagePackageProgress * Double(dept.stats.totalApplications))
        } / Double(totalApplications)
        
        let averageTestingProgress = departmentProgress.reduce(0.0) { sum, dept in
            sum + (dept.stats.averageTestingProgress * Double(dept.stats.totalApplications))
        } / Double(totalApplications)
        
        let latestReadinessDate = departmentProgress.compactMap { $0.stats.latestReadinessDate }.max()
        let latestTestReadinessDate = departmentProgress.compactMap { $0.stats.latestTestReadinessDate }.max()
        
        return DivisionStats(
            totalApplications: totalApplications,
            totalUsers: totalUsers,
            averagePackageProgress: averagePackageProgress,
            averageTestingProgress: averageTestingProgress,
            latestReadinessDate: latestReadinessDate,
            latestTestReadinessDate: latestTestReadinessDate
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Filters Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Department Progress")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        // Division Filter
                        VStack(alignment: .leading) {
                            Text("Division:")
                                .font(.subheadline)
                            Picker("", selection: $selectedDivision) {
                                Text("All Divisions").tag("")
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
                                    Toggle(env, isOn: Binding(
                                        get: { selectedEnvironments.contains(env) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedEnvironments.insert(env)
                                            } else if selectedEnvironments.count > 1 {
                                                selectedEnvironments.remove(env)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        
                        // Status Filter
                        VStack(alignment: .leading) {
                            Text("Status:")
                                .font(.subheadline)
                            Toggle("Exclude Sunset & Out of scope", isOn: $excludeStatusFilter)
                                .toggleStyle(.checkbox)
                        }
                        
                        // Platform Filter
                        VStack(alignment: .leading) {
                            Text("Platform:")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                ForEach(platforms, id: \.self) { platform in
                                    Toggle(platform, isOn: Binding(
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
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(width: 1130)  // Match the total width of the table columns below
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                ScrollView {
                    VStack(spacing: 8) {
                        // Header
                        HStack(spacing: 0) {
                            Text("Department")
                                .frame(width: 200, alignment: .leading)
                                .padding(.leading, 8)
                            Text("Applications")
                                .frame(width: 100, alignment: .center)
                            Text("Users")
                                .frame(width: 100, alignment: .center)
                            VStack(spacing: 0) {
                                Text("Average")
                                Text("Package")
                            }
                            .frame(width: 100, alignment: .center)
                            Text("Ready by")
                                .frame(width: 100, alignment: .center)
                            VStack(spacing: 0) {
                                Text("Average")
                                Text("Testing")
                            }
                            .frame(width: 100, alignment: .center)
                            Text("Ready by")
                                .frame(width: 100, alignment: .center)
                            Text("Department\nProgress")
                                .frame(width: 150, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 1130)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Division header if division is selected
                        if !selectedDivision.isEmpty {
                            Text(selectedDivision)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                                .padding(.vertical, 2)
                        }
                        
                        // Department rows
                        ForEach(departmentProgress, id: \.department) { item in
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    Text(item.department)
                                        .frame(width: 200, alignment: .leading)
                                        .padding(.leading, 8)
                                    Text("\(item.stats.totalApplications)")
                                        .frame(width: 100, alignment: .center)
                                    Text("\(item.stats.totalUsers)")
                                        .frame(width: 100, alignment: .center)
                                    AverageProgressCell(progress: item.stats.averagePackageProgress)
                                        .frame(width: 100)
                                    Text(item.stats.latestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                        .frame(width: 100, alignment: .center)
                                        .font(.system(size: 11))
                                    AverageProgressCell(progress: item.stats.averageTestingProgress)
                                        .frame(width: 100)
                                    Text(item.stats.latestTestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                        .frame(width: 100, alignment: .center)
                                        .font(.system(size: 11))
                                    Text(item.stats.applicationReadinessText)
                                        .frame(width: 150)
                                        .foregroundColor(item.stats.applicationReadinessColor)
                                }
                                .padding(.vertical, 2)
                                Divider()
                                    .padding(.vertical, 1)
                            }
                        }
                        
                        // Totals row
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("Total")
                                    .bold()
                                    .frame(width: 200, alignment: .leading)
                                    .padding(.leading, 8)
                                Text("\(divisionTotals.totalApplications)")
                                    .bold()
                                    .frame(width: 100, alignment: .center)
                                Text("\(divisionTotals.totalUsers)")
                                    .bold()
                                    .frame(width: 100, alignment: .center)
                                AverageProgressCell(progress: divisionTotals.averagePackageProgress)
                                    .frame(width: 100)
                                Text(divisionTotals.latestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                    .bold()
                                    .frame(width: 100, alignment: .center)
                                    .font(.system(size: 11))
                                AverageProgressCell(progress: divisionTotals.averageTestingProgress)
                                    .frame(width: 100)
                                Text(divisionTotals.latestTestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                    .bold()
                                    .frame(width: 100, alignment: .center)
                                    .font(.system(size: 11))
                                Text(divisionTotals.applicationReadinessText)
                                    .bold()
                                    .frame(width: 150)
                                    .foregroundColor(divisionTotals.applicationReadinessColor)
                            }
                            .padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            do {
                isLoading = true
                // First ensure combined records are generated
                _ = try await databaseManager.generateCombinedRecords()
                // Then fetch all records
                records = try await databaseManager.fetchAllRecords()
                isLoading = false
            } catch {
                print("Error loading records: \(error)")
                isLoading = false
            }
        }
    }
}

struct DivisionStats {
    let totalApplications: Int
    let totalUsers: Int
    let averagePackageProgress: Double
    let averageTestingProgress: Double
    let latestReadinessDate: Date?
    let latestTestReadinessDate: Date?
    
    var combinedProgress: Double {
        (averagePackageProgress + averageTestingProgress) / 2.0
    }
    
    var applicationReadinessText: String {
        switch combinedProgress {
        case 0:
            return "Not started"
        case 0.01...20:
            return "Started"
        case 20.01...80:
            return "In progress"
        case 80.01...99.99:
            return "Finishing"
        case 100:
            return "Ready to Migrate"
        default:
            return "Not started"
        }
    }
    
    var applicationReadinessColor: Color {
        switch combinedProgress {
        case 0:
            return .gray
        case 0.01...20:
            return Color.blue.opacity(0.4)
        case 20.01...80:
            return Color.blue.opacity(0.7)
        case 80.01...99.99:
            return Color.blue.opacity(0.9)
        case 100:
            return .green
        default:
            return .gray
        }
    }
}

#Preview {
    DivisionProgressView()
        .environmentObject(DatabaseManager.shared)
} 