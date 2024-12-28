import SwiftUI
import GRDB
import UniformTypeIdentifiers

// Document type for CSV export
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

struct DepartmentProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var selectedDivision: String = ""
    @State private var selectedDepartment: String = ""
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var showResults = false
    @State private var selectedOtapValues: Set<String> = ["P"]  // Default to Production
    @State private var excludeOutOfScope: Bool = true  // New state variable
    @State private var excludeWillBeReplaced: Bool = true  // New state variable for Will Be filter
    @State private var showingExporter = false
    @State private var csvData: Data = Data()
    
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
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Filters Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Department Simple")
                        .font(.headline)
                        .padding(.horizontal, 8)
                    
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
                        
                        // In Scope Filter
                        VStack(alignment: .leading) {
                            Text("Filters:")
                                .font(.subheadline)
                            Toggle("Exclude Out of Scope", isOn: $excludeOutOfScope)
                                .toggleStyle(.checkbox)
                            Toggle("Exclude Will Be Replaced", isOn: $excludeWillBeReplaced)
                                .toggleStyle(.checkbox)
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
                    .padding(.horizontal, 8)
                }
                .frame(width: 1230)  // Match table width
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                if showResults {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Combined header with totals
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(selectedDivision)")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.secondary)
                                        Text("\(selectedDepartment)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 300, alignment: .leading)
                                    .padding(.leading, 8)
                                    Text("Will Be")
                                        .frame(width: 150, alignment: .leading)
                                    Text("Platform")
                                        .frame(width: 100, alignment: .center)
                                    Text("In/Out Scope")
                                        .frame(width: 100, alignment: .center)
                                    Text("Users")
                                        .frame(width: 80, alignment: .center)
                                    Text("Package progress")
                                        .frame(width: 150, alignment: .center)
                                    Text("Ready by")
                                        .frame(width: 100, alignment: .center)
                                    Text("Testing progress")
                                        .frame(width: 150, alignment: .center)
                                    Text("Ready by")
                                        .frame(width: 100, alignment: .center)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 8)
                            }
                            .frame(width: 1230)  // Match table width
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Values row
                            HStack(spacing: 0) {
                                Text("")
                                    .frame(width: 300, alignment: .leading)
                                Text("")  // Will Be total
                                    .frame(width: 150, alignment: .leading)
                                Text("")  // Platform total
                                    .frame(width: 100, alignment: .center)
                                Text("")  // In/Out Scope total
                                    .frame(width: 100, alignment: .center)
                                Text("\(totalUniqueUsers)")
                                    .frame(width: 80, alignment: .center)
                                AverageProgressCell(progress: Double(averagePackageProgress) ?? 0)
                                    .frame(width: 150)
                                Text(latestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                    .frame(width: 100, alignment: .center)
                                    .font(.system(size: 11))
                                AverageProgressCell(progress: Double(averageTestingProgress) ?? 0)
                                    .frame(width: 150)
                                Text(latestTestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                    .frame(width: 100, alignment: .center)
                                    .font(.system(size: 11))
                            }
                            .frame(width: 1230)  // Match table width
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            // Applications List
                            VStack(alignment: .leading, spacing: 4) {
                                // Header
                                HStack(spacing: 0) {
                                    Text("Application")
                                        .frame(width: 300, alignment: .leading)
                                        .padding(.leading, 8)
                                    Text("Will Be")
                                        .frame(width: 150, alignment: .leading)
                                    Text("Platform")
                                        .frame(width: 100, alignment: .center)
                                    Text("In/Out Scope")
                                        .frame(width: 100, alignment: .center)
                                    Text("Users")
                                        .frame(width: 80, alignment: .center)
                                    Text("Package progress")
                                        .frame(width: 150, alignment: .center)
                                    Text("Ready by")
                                        .frame(width: 100, alignment: .center)
                                    Text("Testing progress")
                                        .frame(width: 150, alignment: .center)
                                    Text("Ready by")
                                        .frame(width: 100, alignment: .center)
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
                                        Text(app.willBe ?? "-")
                                            .frame(width: 150, alignment: .leading)
                                        Text(app.platform ?? "-")
                                            .frame(width: 100, alignment: .center)
                                        Text(app.inScopeOutScope ?? "-")
                                            .frame(width: 100, alignment: .center)
                                        Text("\(app.uniqueUsers)")
                                            .frame(width: 80, alignment: .center)
                                        DepartmentProgressCell(status: app.packageStatus)
                                            .frame(width: 150)
                                        Text(app.packageReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                            .frame(width: 100, alignment: .center)
                                            .font(.system(size: 11))
                                        DepartmentProgressCell(status: app.testingStatus)
                                            .frame(width: 150)
                                        Text(app.testReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                                            .frame(width: 100, alignment: .center)
                                            .font(.system(size: 11))
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(width: 1230)  // Match table width
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Divider()
                
                // Export bar
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            csvData = await generateCSVData()
                            showingExporter = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export to CSV")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!showResults)
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .padding(.horizontal, 0)  // Remove horizontal padding
        .padding(.vertical)  // Keep vertical padding
        .task {
            await loadData()
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: CSVDocument(data: csvData),
            contentType: .commaSeparatedText,
            defaultFilename: "\(selectedDepartment)_progress"
        ) { result in
            if case .success = result {
                print("Successfully exported CSV")
            }
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
        let uniqueUsers: Int
        let packageStatus: String
        let packageReadinessDate: Date?
        let testingStatus: String
        let testReadinessDate: Date?
        let migrationStatus: String
        let willBe: String?
        let platform: String?
        let inScopeOutScope: String?
        let isWillBeApplication: Bool
    }
    
    private var departmentApplications: [ApplicationInfo] {
        let filteredRecords = records.filter { record in
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOtapValues.contains(record.otap) &&
            (!excludeOutOfScope || record.inScopeOutScopeDivision?.lowercased() != "out") &&
            (!excludeWillBeReplaced || record.willBe == nil)  // Filter out applications that will be replaced
        }
        
        let groupedByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
        // First, create ApplicationInfo for all current applications
        var applications = groupedByApp.map { appName, records in
            let uniqueUsers = Set(records.map { $0.systemAccount }).count
            let packageStatus = records.first?.applicationPackageStatus ?? "Not Started"
            let packageReadinessDate = records.first?.applicationPackageReadinessDate
            let testingStatus = records.first?.applicationTestStatus ?? "Not Started"
            let testReadinessDate = records.first?.applicationTestReadinessDate
            let migrationStatus = records.first?.migrationReadiness ?? "Not Started"
            // Treat "N/A" the same as nil or empty string
            let willBe = records.first?.willBe
            let normalizedWillBe = willBe == "N/A" ? nil : willBe
            let platform = records.first?.migrationPlatform
            let normalizedPlatform = platform == "N/A" ? nil : platform
            let inScopeOutScope = records.first?.inScopeOutScopeDivision
            
            return ApplicationInfo(
                name: appName,
                uniqueUsers: uniqueUsers,
                packageStatus: packageStatus,
                packageReadinessDate: packageReadinessDate,
                testingStatus: testingStatus,
                testReadinessDate: testReadinessDate,
                migrationStatus: migrationStatus,
                willBe: normalizedWillBe,
                platform: normalizedPlatform,
                inScopeOutScope: inScopeOutScope,
                isWillBeApplication: false
            )
        }
        
        // Then add Will Be applications if they don't already exist
        let willBeApps = applications.filter { $0.willBe != nil }
        for app in willBeApps {
            if let willBeName = app.willBe {
                // Check if this Will Be application already exists in current list
                if applications.contains(where: { $0.name == willBeName }) {
                    // Don't update existing apps in the current view
                    continue
                } else {
                    // Look up the Will Be application in all records
                    let willBeRecords = records.filter { $0.applicationName == willBeName }
                    
                    if let existingRecord = willBeRecords.first {
                        // Use the actual progress data from the existing application
                        let willBeApp = ApplicationInfo(
                            name: willBeName,
                            uniqueUsers: app.uniqueUsers,
                            packageStatus: existingRecord.applicationPackageStatus ?? "Not Started",
                            packageReadinessDate: existingRecord.applicationPackageReadinessDate,
                            testingStatus: existingRecord.applicationTestStatus ?? "Not Started",
                            testReadinessDate: existingRecord.applicationTestReadinessDate,
                            migrationStatus: existingRecord.migrationReadiness ?? "Not Started",
                            willBe: nil,
                            platform: app.platform,
                            inScopeOutScope: app.inScopeOutScope,
                            isWillBeApplication: true
                        )
                        applications.append(willBeApp)
                    } else {
                        // If no existing record found, create new with Not Started
                        let willBeApp = ApplicationInfo(
                            name: willBeName,
                            uniqueUsers: app.uniqueUsers,
                            packageStatus: "Not Started",
                            packageReadinessDate: nil,
                            testingStatus: "Not Started",
                            testReadinessDate: nil,
                            migrationStatus: app.migrationStatus,
                            willBe: nil,
                            platform: app.platform,
                            inScopeOutScope: app.inScopeOutScope,
                            isWillBeApplication: true
                        )
                        applications.append(willBeApp)
                    }
                }
            }
        }
        
        return applications.sorted { $0.name < $1.name }
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
        // Filter to only in-scope applications that are either:
        // 1. Not being replaced (no willBe value)
        // 2. Are Will Be applications themselves
        let validApps = departmentApplications.filter { app in
            app.inScopeOutScope?.lowercased() != "out" &&
            (app.willBe == nil || app.isWillBeApplication)
        }
        
        let total = validApps.reduce(0.0) { sum, app in
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
            return sum + points
        }
        let average = validApps.isEmpty ? 0.0 : total / Double(validApps.count)
        return String(format: "%.0f", average)
    }
    
    private var averageTestingProgress: String {
        // Filter to only in-scope applications that are either:
        // 1. Not being replaced (no willBe value)
        // 2. Are Will Be applications themselves
        let validApps = departmentApplications.filter { app in
            app.inScopeOutScope?.lowercased() != "out" &&
            (app.willBe == nil || app.isWillBeApplication)
        }
        
        let total = validApps.reduce(0.0) { sum, app in
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
            return sum + points
        }
        let average = validApps.isEmpty ? 0.0 : total / Double(validApps.count)
        return String(format: "%.0f", average)
    }
    
    private var averageMigrationProgress: String {
        let total = departmentApplications.reduce(0.0) { sum, app in
            sum + (app.migrationStatus.lowercased() == "ready" ? 100.0 :
                  app.migrationStatus.lowercased() == "in progress" ? 50.0 : 0.0)
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
    
    private func generateCSVData() async -> Data {
        var csv = "Application Name,Will Be,Platform,In/Out Scope,Users,Package Status,Package Ready By,Testing Status,Testing Ready By\n"
        
        for app in departmentApplications {
            let packageDate = app.packageReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? ""
            let testDate = app.testReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? ""
            
            let row = [
                app.name,
                app.willBe ?? "",
                app.platform ?? "",
                app.inScopeOutScope ?? "",
                String(app.uniqueUsers),
                app.packageStatus,
                packageDate,
                app.testingStatus,
                testDate
            ].map { "\"\($0)\"" }.joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
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