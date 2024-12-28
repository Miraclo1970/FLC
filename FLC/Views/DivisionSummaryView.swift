import SwiftUI
import GRDB

struct DivisionProgressView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    @State private var selectedOtapValues: Set<String> = ["P"]  // Default to Production
    
    private let otapValues = ["O", "T", "A", "P"]
    
    // Available divisions
    private var divisions: [String] {
        Array(Set(records.compactMap { $0.division }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    // Get departments for a specific division
    private func departments(for division: String) -> [String] {
        Array(Set(records.filter { $0.division == division }
            .compactMap { $0.departmentSimple }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    // Count active applications (excluding Will Be and Out of Scope)
    private var activeApplicationsCount: Int {
        Set(records.filter { record in
            selectedOtapValues.contains(record.otap) &&
            (record.willBe ?? "").isEmpty &&
            (record.inScopeOutScopeDivision?.lowercased() != "out")
        }.map { $0.applicationName }).count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Overview Bar
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Active Applications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(activeApplicationsCount)")
                                .font(.title2.bold())
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor)))
                    
                    // OTAP Filter
                    HStack {
                        Text("OTAP:")
                            .font(.subheadline)
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
                            .toggleStyle(.switch)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Tabs for divisions
                TabView {
                    ForEach(divisions, id: \.self) { division in
                        DivisionTabContent(
                            division: division,
                            departments: departments(for: division),
                            records: records,
                            selectedOtapValues: selectedOtapValues
                        )
                        .tabItem {
                            Text(division)
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
}

struct DivisionTabContent: View {
    let division: String
    let departments: [String]
    let records: [CombinedRecord]
    let selectedOtapValues: Set<String>
    
    // Count active applications for this division
    private var activeApplicationsCount: Int {
        Set(records.filter { record in
            record.division == division &&
            selectedOtapValues.contains(record.otap) &&
            (record.willBe ?? "").isEmpty &&
            (record.inScopeOutScopeDivision?.lowercased() != "out")
        }.map { $0.applicationName }).count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Division header with active apps count
                HStack {
                    Text("\(division)")
                        .font(.title2.bold())
                    Spacer()
                    Text("# Apps: \(activeApplicationsCount)")
                        .font(.headline)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Header
                HStack(spacing: 0) {
                    Text("Department")
                        .frame(width: 300, alignment: .leading)
                    Text("# Apps")
                        .frame(width: 80, alignment: .center)
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
                .padding(.horizontal)
                .background(Color(NSColor.controlBackgroundColor))
                
                // Department rows
                ForEach(departments, id: \.self) { department in
                    DepartmentRow(
                        division: division,
                        department: department,
                        records: records,
                        selectedOtapValues: selectedOtapValues
                    )
                    Divider()
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct DepartmentRow: View {
    let division: String
    let department: String
    let records: [CombinedRecord]
    let selectedOtapValues: Set<String>
    
    private var departmentRecords: [CombinedRecord] {
        records.filter { record in
            record.division == division &&
            record.departmentSimple == department &&
            selectedOtapValues.contains(record.otap)
        }
    }
    
    private var uniqueUsers: Int {
        Set(departmentRecords.map { $0.systemAccount }).count
    }
    
    private var packageProgress: Double {
        let validApps = departmentRecords.filter { $0.inScopeOutScopeDivision?.lowercased() != "out" }
        let total = validApps.reduce(0.0) { sum, record in
            let status = (record.applicationPackageStatus ?? "").lowercased()
            let points = {
                if status == "ready" || status == "ready for testing" {
                    return 100.0
                } else if status == "in progress" {
                    return 50.0
                } else {
                    return 0.0
                }
            }()
            return sum + points
        }
        return validApps.isEmpty ? 0.0 : total / Double(validApps.count)
    }
    
    private var testingProgress: Double {
        let validApps = departmentRecords.filter { $0.inScopeOutScopeDivision?.lowercased() != "out" }
        let total = validApps.reduce(0.0) { sum, record in
            let status = (record.applicationTestStatus ?? "").lowercased()
            let points = {
                switch status {
                case "ready", "completed", "passed":
                    return 100.0
                case "in progress":
                    return 50.0
                default:
                    return 0.0
                }
            }()
            return sum + points
        }
        return validApps.isEmpty ? 0.0 : total / Double(validApps.count)
    }
    
    private var latestPackageReadinessDate: Date? {
        departmentRecords
            .compactMap { $0.applicationPackageReadinessDate }
            .max()
    }
    
    private var latestTestReadinessDate: Date? {
        departmentRecords
            .compactMap { $0.applicationTestReadinessDate }
            .max()
    }
    
    private var activeApplicationsCount: Int {
        Set(departmentRecords.filter { record in
            (record.willBe ?? "").isEmpty &&
            (record.inScopeOutScopeDivision?.lowercased() != "out")
        }.map { $0.applicationName }).count
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text(department)
                .frame(width: 300, alignment: .leading)
            Text("\(activeApplicationsCount)")
                .frame(width: 80, alignment: .center)
            Text("\(uniqueUsers)")
                .frame(width: 80, alignment: .center)
            AverageProgressCell(progress: packageProgress)
                .frame(width: 150)
            Text(latestPackageReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                .frame(width: 100, alignment: .center)
                .font(.system(size: 11))
            AverageProgressCell(progress: testingProgress)
                .frame(width: 150)
            Text(latestTestReadinessDate.map { DateFormatter.shortDateFormatter.string(from: $0) } ?? "-")
                .frame(width: 100, alignment: .center)
                .font(.system(size: 11))
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}

#Preview {
    DivisionProgressView()
        .environmentObject(DatabaseManager.shared)
} 