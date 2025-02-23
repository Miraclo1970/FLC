import SwiftUI
import GRDB

struct ChecklistAppUserView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    
    // Filter states
    @State private var selectedDivision = ""
    @State private var selectedDepartment = ""
    @State private var divisions: [String] = []
    @State private var departments: [String] = []
    @State private var selectedOTAP: Set<String> = ["P"]
    private let otapOptions = ["A", "OT", "P", "Prullenbak", "TW", "VDI"]
    
    // Additional filters
    @State private var excludeOutScope = true
    @State private var excludeWillBeAndSunset = true
    @State private var excludeNoHROrLeftUsers = true
    
    // Matrix data
    @State private var applications: [String] = []
    @State private var users: [String] = []
    @State private var usageMatrix: [String: Set<String>] = [:] // [applicationName: Set<userNames>]
    
    @State private var isExporting = false
    @State private var exportError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading data...")
            } else {
                // Filters section
                HStack(spacing: 20) {
                    // Division Filter
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Division")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Picker("Select Division", selection: $selectedDivision) {
                            Text("Select Division").tag("")
                            ForEach(divisions, id: \.self) { division in
                                Text(division).tag(division)
                            }
                        }
                        .frame(width: 200)
                        .onChange(of: selectedDivision) { oldValue, newValue in
                            selectedDepartment = ""
                            updateDepartments()
                            updateMatrix()
                        }
                    }
                    
                    // Department Filter
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Department")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Picker("Select Department", selection: $selectedDepartment) {
                            Text("Select Department").tag("")
                            ForEach(departments, id: \.self) { department in
                                Text(department).tag(department)
                            }
                        }
                        .frame(width: 200)
                        .disabled(selectedDivision.isEmpty)
                        .onChange(of: selectedDepartment) { oldValue, newValue in
                            updateMatrix()
                        }
                    }
                    
                    // OTAP Filter
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OTAP")
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
                                        updateMatrix()
                                    }
                                )) {
                                    Text(option)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                    
                    // Additional Filters
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Additional Filters")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Toggle("Exclude out scope & out scope division", isOn: $excludeOutScope)
                            .onChange(of: excludeOutScope) { _, _ in updateMatrix() }
                        
                        Toggle("Exclude sunset and show only Will be app", isOn: $excludeWillBeAndSunset)
                            .onChange(of: excludeWillBeAndSunset) { _, _ in updateMatrix() }
                        
                        Toggle("Exclude users who have left", isOn: $excludeNoHROrLeftUsers)
                            .onChange(of: excludeNoHROrLeftUsers) { _, _ in updateMatrix() }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor)))
                
                if selectedDivision.isEmpty || selectedDepartment.isEmpty {
                    VStack {
                        Text("Please select both Division and Department")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Matrix View
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header row with user names
                            HStack(spacing: 0) {
                                Text("Applications")
                                    .frame(width: 300, alignment: .leading)
                                    .padding(.leading, 4)
                                    .font(.system(size: 12, weight: .bold))
                                Text("Will be")
                                    .frame(width: 100, alignment: .leading)
                                    .font(.system(size: 12, weight: .bold))
                                Text("Out of Scope")
                                    .frame(width: 100, alignment: .leading)
                                    .font(.system(size: 12, weight: .bold))
                                
                                ForEach(users, id: \.self) { user in
                                    VStack {
                                        Text(user)
                                            .font(.system(size: 9))
                                            .frame(width: 100)  // This controls text width after rotation
                                            .rotationEffect(.degrees(-90))
                                            .offset(y: -20)  // Keep the same distance to first row
                                    }
                                    .frame(width: 20)  // Column width
                                    .padding(.top, 40)  // Increased padding to prevent cutoff at the top
                                }
                            }
                            .padding(.bottom, 4)
                            
                            // Application rows
                            ForEach(applications, id: \.self) { app in
                                HStack(spacing: 0) {
                                    Text(app)
                                        .frame(width: 300, alignment: .leading)
                                        .padding(.leading, 4)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    Text(getWillBeValue(for: app))
                                        .frame(width: 100, alignment: .leading)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    Text(getOutOfScopeValue(for: app))
                                        .frame(width: 100, alignment: .leading)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    
                                    ForEach(users, id: \.self) { user in
                                        Text(usageMatrix[app]?.contains(user) == true ? "•" : "")
                                            .frame(width: 20, height: 16)
                                            .font(.system(size: 14, weight: .black))
                                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                            .border(Color.gray.opacity(0.1), width: 0.5)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Export Bar
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Text("Export Application Usage Matrix")
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
                        .disabled(isExporting || selectedDivision.isEmpty || selectedDepartment.isEmpty)
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
    
    private func loadData() async {
        do {
            isLoading = true
            records = try await databaseManager.fetchAllRecords()
            
            // Load divisions
            let uniqueDivisions = Set(records.compactMap { $0.division })
            divisions = uniqueDivisions.sorted()
            
            isLoading = false
        } catch {
            print("Error loading records: \(error)")
            isLoading = false
        }
    }
    
    private func updateDepartments() {
        guard !selectedDivision.isEmpty else {
            departments = []
            return
        }
        
        let filteredRecords = records.filter { record in
            record.division == selectedDivision
        }
        
        let uniqueDepartments = Set(filteredRecords.compactMap { $0.departmentSimple })
        departments = uniqueDepartments.sorted()
    }
    
    private func updateMatrix() {
        guard !selectedDivision.isEmpty && !selectedDepartment.isEmpty else {
            applications = []
            users = []
            usageMatrix = [:]
            return
        }
        
        // Filter records based on selected filters
        let filteredRecords = records.filter { record in
            // Basic filters
            let divisionMatch = record.division == selectedDivision
            let departmentMatch = record.departmentSimple == selectedDepartment
            let otapMatch = selectedOTAP.contains(record.otap)
            
            // Out scope filter
            let outScopeMatch = !excludeOutScope || 
                (record.inScopeOutScopeDivision?.lowercased() != "out" &&
                 !(record.inScopeOutScopeDivision?.lowercased().starts(with: "out ") ?? false))
            
            // Left users filter - only check leave date
            let leftUserMatch = !excludeNoHROrLeftUsers ||
                (record.leaveDate == nil || record.leaveDate! > Date())
            
            return divisionMatch && departmentMatch && otapMatch && outScopeMatch && leftUserMatch
        }
        
        // Build initial matrix of all applications and their users
        var fullMatrix: [String: Set<String>] = [:]
        var willBeSourceApps: Set<String> = []
        
        // Group records by application name for easier processing
        let recordsByApp = Dictionary(grouping: filteredRecords) { $0.applicationName }
        
        // First pass: Add all applications and their direct users
        // Also collect applications that will be migrated
        for (appName, appRecords) in recordsByApp {
            let appUsers = Set(appRecords.map { $0.systemAccount })
            fullMatrix[appName] = appUsers
            
            // If this app has a "will be" target, mark it for potential removal
            if let willBe = appRecords.first?.willBe,
               !willBe.isEmpty && willBe != "N/A" {
                willBeSourceApps.insert(appName)
            }
        }
        
        // Second pass: Process will-be relationships and merge users
        for (appName, appRecords) in recordsByApp {
            // Get the will-be value for this application (if any)
            guard let willBeApp = appRecords.first?.willBe,
                  !willBeApp.isEmpty && willBeApp != "N/A" else {
                continue
            }
            
            // Get users for this application
            let appUsers = Set(appRecords.map { $0.systemAccount })
            
            // Merge users into the target application
            fullMatrix[willBeApp, default: []].formUnion(appUsers)
            
            // If exclude filter is on, remove the source application
            if excludeWillBeAndSunset {
                fullMatrix.removeValue(forKey: appName)
            }
        }
        
        // Update view state
        applications = Array(fullMatrix.keys).sorted()
        users = Array(Set(filteredRecords.map { $0.systemAccount })).sorted()
        usageMatrix = fullMatrix
        
        print("\nMatrix Summary:")
        print("Total Applications: \(applications.count)")
        print("Total Users: \(users.count)")
        
        // Debug information
        print("\nWill-be relationships:")
        for (app, users) in fullMatrix {
            let willBe = recordsByApp[app]?.first?.willBe ?? "N/A"
            if willBe != "N/A" {
                print("\(app) -> \(willBe): \(users.count) users")
            }
        }
    }
    
    private func exportAsCSV() {
        isExporting = true
        exportError = nil
        
        Task {
            do {
                // Get save location from user
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = "application_usage_matrix_\(selectedDivision)_\(selectedDepartment).csv"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = panel.url {
                    // Create CSV content
                    var csvContent = "Division: \(selectedDivision)\n"
                    csvContent += "Department: \(selectedDepartment)\n"
                    csvContent += "OTAP Environments: \(Array(selectedOTAP).sorted().joined(separator: ", "))\n\n"
                    
                    // Add header row with usernames
                    csvContent += "Application,Will be,Out of Scope," + users.joined(separator: ",") + "\n"
                    
                    // Add application rows
                    for app in applications {
                        let row = [app, getWillBeValue(for: app), getOutOfScopeValue(for: app)] + users.map { user in
                            usageMatrix[app]?.contains(user) == true ? "X" : ""
                        }
                        csvContent += row.joined(separator: ",") + "\n"
                    }
                    
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
    
    private func getWillBeValue(for app: String) -> String {
        // Find the first record for this application that has a willBe value
        let appRecords = records.filter { record in
            record.applicationName == app &&
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOTAP.contains(record.otap)
        }
        return appRecords.first?.willBe ?? "N/A"
    }
    
    private func getOutOfScopeValue(for app: String) -> String {
        // Find the first record for this application that has an out of scope value
        let appRecords = records.filter { record in
            record.applicationName == app &&
            record.division == selectedDivision &&
            record.departmentSimple == selectedDepartment &&
            selectedOTAP.contains(record.otap)
        }
        return appRecords.first?.inScopeOutScopeDivision ?? "N/A"
    }
}

#Preview {
    ChecklistAppUserView()
        .environmentObject(DatabaseManager.shared)
} 