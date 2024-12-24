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
                    Text("Select Department")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        // Division Picker
                        VStack(alignment: .leading) {
                            Text("Division:")
                                .font(.subheadline)
                            Picker("Division", selection: $selectedDivision) {
                                Text("Select Division").tag("")
                                ForEach(divisions, id: \.self) { division in
                                    Text(division).tag(division)
                                }
                            }
                            .frame(width: 200)
                        }
                        
                        // Department Picker (enabled only when division is selected)
                        VStack(alignment: .leading) {
                            Text("Department:")
                                .font(.subheadline)
                            Picker("Department", selection: $selectedDepartment) {
                                Text("Select Department").tag("")
                                ForEach(departments, id: \.self) { department in
                                    Text(department).tag(department)
                                }
                            }
                            .frame(width: 200)
                            .disabled(selectedDivision.isEmpty)
                        }
                        
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
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                if showResults {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Header with department info
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Division: \(selectedDivision)")
                                        .font(.headline)
                                    Text("Department: \(selectedDepartment)")
                                        .font(.headline)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Total Unique Users: \(totalUniqueUsers)")
                                        .font(.headline)
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Applications List
                            VStack(alignment: .leading, spacing: 4) {
                                // Header
                                HStack(spacing: 0) {
                                    Text("Application")
                                        .frame(width: 400, alignment: .leading)
                                    Text("Users")
                                        .frame(width: 80, alignment: .center)
                                    Text("Package progress")
                                        .frame(width: 150, alignment: .center)
                                    Text("Testing progress")
                                        .frame(width: 150, alignment: .center)
                                    Text("Migration progress")
                                        .frame(width: 150, alignment: .center)
                                }
                                .font(.headline)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                
                                // Application rows
                                ForEach(departmentApplications, id: \.name) { app in
                                    HStack(spacing: 0) {
                                        Text(app.name)
                                            .frame(width: 400, alignment: .leading)
                                            .lineLimit(1)
                                        Text("\(app.uniqueUsers)")
                                            .frame(width: 80, alignment: .center)
                                        DepartmentProgressCell(status: app.packageStatus)
                                            .frame(width: 150)
                                        DepartmentProgressCell(status: app.testingStatus)
                                            .frame(width: 150)
                                        DepartmentProgressCell(status: app.migrationStatus)
                                            .frame(width: 150)
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
        let uniqueUsers: Int
        let packageStatus: String
        let testingStatus: String
        let migrationStatus: String
    }
    
    private var departmentApplications: [ApplicationInfo] {
        let filteredRecords = records.filter { record in
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOtapValues.contains(record.otap)
        }
        
        let groupedByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
        return groupedByApp.map { appName, records in
            let uniqueUsers = Set(records.map { $0.systemAccount }).count
            let packageStatus = records.first?.applicationPackageStatus ?? "Not Started"
            let testingStatus = records.first?.applicationTestStatus ?? "Not Started"
            let migrationStatus = records.first?.migrationReadiness ?? "Not Started"
            
            return ApplicationInfo(
                name: appName,
                uniqueUsers: uniqueUsers,
                packageStatus: packageStatus,
                testingStatus: testingStatus,
                migrationStatus: migrationStatus
            )
        }.sorted { $0.name < $1.name }
    }
    
    private var totalUniqueUsers: Int {
        let filteredRecords = records.filter { record in
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOtapValues.contains(record.otap)
        }
        return Set(filteredRecords.map { $0.systemAccount }).count
    }
}

struct DepartmentProgressCell: View {
    let status: String
    
    private var progress: Double {
        switch status.lowercased() {
        case "ready":
            return 100.0
        case "in progress":
            return 50.0
        case "not started":
            return 0.0
        default:
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

#Preview {
    DepartmentProgressView()
        .environmentObject(DatabaseManager.shared)
} 