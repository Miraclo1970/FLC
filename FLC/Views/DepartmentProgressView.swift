import SwiftUI
import GRDB

struct DepartmentProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var selectedDivision: String = ""
    @State private var selectedDepartment: String = ""
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var showResults = false
    @State private var selectedOtapValues: Set<String> = ["P"]  // Default to Production
    
    private let otapValues = ["O", "T", "A", "P"]
    
    // Available divisions and departments
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var departments: [String] {
        Array(Set(records.filter { $0.division == selectedDivision }
            .compactMap { $0.departmentSimple }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Filters Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Department Simple")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        // Division Picker
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
                        
                        // Department Simple Picker
                        VStack(alignment: .leading) {
                            Text("Department Simple:")
                                .font(.subheadline)
                            Picker("", selection: $selectedDepartment) {
                                Text("Select Department Simple").tag("")
                                ForEach(departments, id: \.self) { department in
                                    Text(department).tag(department)
                                }
                            }
                            .frame(width: 200)
                            .disabled(selectedDivision.isEmpty)
                        }
                        
                        Spacer()
                        
                        // OTAP Filter
                        VStack(alignment: .leading) {
                            Text("OTAP:")
                                .font(.subheadline)
                            HStack {
                                ForEach(otapValues, id: \.self) { value in
                                    Toggle(value, isOn: Binding(
                                        get: { selectedOtapValues.contains(value) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedOtapValues.insert(value)
                                            } else {
                                                selectedOtapValues.remove(value)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        
                        // Generate Button
                        Button(action: {
                            showResults = true
                        }) {
                            Text("Generate")
                                .frame(width: 100)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedDivision.isEmpty || selectedDepartment.isEmpty || selectedOtapValues.isEmpty)
                    }
                    .frame(width: 1130)  // Match the total width of the table columns below
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                if showResults {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Combined header with totals
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
                                Text("Application\nReadiness")
                                    .frame(width: 120, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 1130)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Values row
                            HStack(spacing: 0) {
                                Text("")
                                    .frame(width: 300, alignment: .leading)
                                    .padding(.leading, 8)
                                Text("")
                                    .frame(width: 100, alignment: .leading)
                                Text("")
                                    .frame(width: 80, alignment: .leading)
                                Text("")
                                    .frame(width: 80, alignment: .leading)
                                Text("\(totalUniqueUsers)")
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
                                AverageProgressCell(progress: Double(averageMigrationProgress) ?? 0)
                                    .frame(width: 120)
                            }
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            // Applications List
                            VStack(alignment: .leading, spacing: 4) {
                                // Header
                                HStack(spacing: 0) {
                                    Text("Application")
                                        .frame(width: 300, alignment: .leading)
                                        .padding(.leading, 8)
                                    Text("Will be")
                                        .frame(width: 100, alignment: .leading)
                                    Text("Platform")
                                        .frame(width: 80, alignment: .leading)
                                    Text("In/Out Scope")
                                        .frame(width: 80, alignment: .leading)
                                    Text("Users")
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
                                    Text("Application\nReadiness")
                                        .frame(width: 120, alignment: .center)
                                        .multilineTextAlignment(.center)
                                }
                                .font(.headline)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                
                                // Application rows
                                ForEach(departmentApplications, id: \.name) { app in
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
                                        DepartmentProgressCell(status: app.packageStatus)
                                            .frame(width: 120)
                                        Text(app.packageReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                            .frame(width: 80, alignment: .center)
                                            .font(.system(size: 11))
                                        DepartmentProgressCell(status: app.testingStatus)
                                            .frame(width: 120)
                                        Text(app.testReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                            .frame(width: 80, alignment: .center)
                                            .font(.system(size: 11))
                                        Text(app.applicationReadiness)
                                            .frame(width: 120)
                                            .foregroundColor({
                                                switch app.applicationReadiness {
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
                                            }())
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
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
    
    private struct ApplicationInfo: Identifiable {
        let id = UUID()
        let name: String
        let willBe: String
        let platform: String
        let inOutScope: String
        let uniqueUsers: Int
        let packageStatus: String
        let packageReadinessDate: Date?
        let testingStatus: String
        let testReadinessDate: Date?
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
                case "ready", "completed", "passed":
                    return 100.0
                case "in progress":
                    return 50.0
                default:
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
        // First, filter AD records by division, department, and OTAP
        let filteredRecords = records.filter { record in
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOtapValues.contains(record.otap)
        }
        
        // Group by application name to count unique users
        let groupedByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
        // Create a set of all "Will be" targets
        let willBeTargets = Set(filteredRecords.compactMap { $0.willBe }
            .filter { !$0.isEmpty && $0 != "N/A" })
        
        // Convert to ApplicationInfo array
        return groupedByApp.map { appName, records in
            let uniqueUsers = Set(records.map { $0.systemAccount }).count
            let firstRecord = records.first
            
            // If this app is a "Will be" target, use its platform info
            let platform: String
            if willBeTargets.contains(appName) {
                // Find records where this app is the target
                let targetRecords = filteredRecords.filter { record in 
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
                packageStatus: firstRecord?.applicationPackageStatus ?? "Not Started",
                packageReadinessDate: firstRecord?.applicationPackageReadinessDate,
                testingStatus: firstRecord?.applicationTestStatus ?? "Not Started",
                testReadinessDate: firstRecord?.applicationTestReadinessDate
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    private var totalUniqueUsers: Int {
        let filteredRecords = records.filter { record in
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOtapValues.contains(record.otap)
        }
        return Set(filteredRecords.map { $0.systemAccount }).count
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
                case "ready", "completed", "passed":
                    return 100.0
                case "in progress":
                    return 50.0
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
}

struct DepartmentProgressCell: View {
    let status: String
    
    private var progress: Double {
        let lowercasedStatus = status.lowercased()
        
        // Package status specific
        if lowercasedStatus == "ready for testing" {
            return 100.0
        }
        
        // Common statuses
        switch lowercasedStatus {
        case "ready", "completed", "passed":
            return 100.0
        case "in progress":
            return 50.0
        case "not started", "":
            return 0.0
        default:
            print("Unknown status: \(status)")
            return 0.0
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ProgressView(value: progress, total: 100)
                .frame(width: 80, height: 6)
            Text(String(format: "%.0f%%", progress))
                .font(.system(size: 11))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }
}

struct AverageProgressCell: View {
    let progress: Double
    
    var body: some View {
        HStack(spacing: 4) {
            ProgressView(value: progress, total: 100)
                .frame(width: 80, height: 6)
            Text(String(format: "%.0f%%", progress))
                .font(.system(size: 11))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 8)
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