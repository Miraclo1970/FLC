import SwiftUI
import GRDB

struct BaselineApplicationsUsageView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdateTime = Date()
    @State private var lastADImportDate: Date?
    @State private var lastHRImportDate: Date?
    @State private var showingSavePanel = false
    @State private var applicationsWithFewUsers: Set<String> = []
    @State private var applicationsWithOneUser: Set<String> = []
    @State private var usersWithFewApps: Set<String> = []
    @State private var usersWithoutApps: Set<String> = []
    @State private var exportType: ExportType = .fewUsers
    @State private var divisionCounts: [(division: String, count: Int)] = []
    @State private var totalApplicationCount: Int = 0
    @State private var mostUsedApplications: [(name: String, userCount: Int)] = []
    @State private var totalUsers: Int = 0
    
    // OTAP filter states
    @State private var selectedOTAP: Set<String> = ["P"]
    private let otapOptions = ["A", "OT", "P", "Prullenbak", "TW", "VDI"]
    
    // Division filter states
    @State private var selectedDivision: String = "All"
    @State private var divisions: [String] = ["All"]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            // Filter section
            VStack(spacing: 20) {
                HStack(spacing: 20) {
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
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor)))
                    
                    // Division Filter
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Division Filter")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker("Division", selection: $selectedDivision) {
                            ForEach(divisions, id: \.self) { division in
                                Text(division).tag(division)
                            }
                        }
                        .frame(width: 200)
                        .onChange(of: selectedDivision) { oldValue, newValue in
                            Task {
                                await loadData()
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor)))
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            
            // Timestamps and Pie Chart side by side
            HStack(alignment: .top, spacing: 20) {
                // Timestamps
                VStack(alignment: .leading, spacing: 8) {
                    Text("Baseline check: \(dateFormatter.string(from: lastUpdateTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let adDate = lastADImportDate {
                        Text("Last AD import: \(dateFormatter.string(from: adDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let hrDate = lastHRImportDate {
                        Text("Last HR import: \(dateFormatter.string(from: hrDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                if selectedDivision == "All" {
                    // Division Distribution Pie Chart
                    VStack {
                        Text("Applications per Division")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        ZStack {
                            if !divisionCounts.isEmpty {
                                ForEach(Array(divisionCounts.enumerated()), id: \.element.division) { index, item in
                                    let startAngle = index == 0 ? 0.0 : divisionCounts.prefix(index).reduce(0.0) { sum, curr in
                                        sum + (Double(curr.count) / Double(totalApplicationCount)) * 360
                                    }
                                    let endAngle = startAngle + (Double(item.count) / Double(totalApplicationCount)) * 360
                                    
                                    PieSlice(startAngle: startAngle, endAngle: endAngle)
                                        .fill(Color.blue.opacity(0.1 + Double(index) * 0.1))
                                }
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            }
                        }
                        .frame(width: 200, height: 200)
                        
                        // Legend
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(divisionCounts.enumerated()), id: \.element.division) { index, item in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1 + Double(index) * 0.1))
                                        .frame(width: 12, height: 12)
                                    Text("\(item.division) (\(item.count))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                } else {
                    // Most Used Applications List
                    VStack {
                        Text("Most Used Applications in \(selectedDivision)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        
                        Text("(Accounting for 80% of users)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(mostUsedApplications, id: \.name) { app in
                                HStack {
                                    Text(app.name)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(app.userCount) users (\(Int((Double(app.userCount) / Double(totalUsers)) * 100))%)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(width: 300)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor)))
                }
            }
            
            // Statistics boxes
            HStack(spacing: 20) {
                // Applications with less than 5 users
                VStack(alignment: .leading, spacing: 8) {
                    Text("Applications with < 5 Users")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(applicationsWithFewUsers.count)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
                
                // Applications with exactly 1 user
                VStack(alignment: .leading, spacing: 8) {
                    Text("Applications with 1 User")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(applicationsWithOneUser.count)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )

                // Users with 1-5 applications
                VStack(alignment: .leading, spacing: 8) {
                    Text("Users with 1-5 Applications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(usersWithFewApps.count)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )

                // Users without applications
                VStack(alignment: .leading, spacing: 8) {
                    Text("Users without Applications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(usersWithoutApps.count)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding()
            
            // Download buttons
            VStack(spacing: 10) {
                Text("Download Options")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Button(action: { 
                        exportType = .fewUsers
                        showingSavePanel = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Applications with < 5 Users")
                        }
                        .padding()
                        .frame(width: 300)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { 
                        exportType = .oneUser
                        showingSavePanel = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Applications with 1 User")
                        }
                        .padding()
                        .frame(width: 300)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadDivisions()
            await loadData()
        }
        .fileExporter(
            isPresented: $showingSavePanel,
            document: ApplicationsCSVDocument(
                applications: exportType == .fewUsers ? applicationsWithFewUsers : applicationsWithOneUser,
                timestamp: lastUpdateTime,
                exportType: exportType,
                adImportDate: lastADImportDate,
                hrImportDate: lastHRImportDate
            ),
            contentType: .commaSeparatedText,
            defaultFilename: "\(exportType == .fewUsers ? "applications_with_few_users" : "applications_with_one_user")_\(formatDateForFilename(lastUpdateTime)).csv"
        ) { result in
            if case .failure(let error) = result {
                print("Export error: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
    
    private func loadDivisions() async {
        do {
            let records = try await DatabaseManager.shared.fetchCombinedRecords()
            let uniqueDivisions = Set(records.compactMap { $0.division })
            await MainActor.run {
                divisions = ["All"] + uniqueDivisions.sorted()
            }
        } catch {
            print("Error loading divisions: \(error.localizedDescription)")
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            // Update timestamp first
            await MainActor.run {
                lastUpdateTime = Date()
            }
            
            // Get combined records
            let combinedRecords = try await DatabaseManager.shared.fetchCombinedRecords()
            
            // Get last import dates from AD and HR records
            let adImportDate = try await DatabaseManager.shared.getLatestImportDate(from: "ad_records")
            let hrImportDate = try await DatabaseManager.shared.getLatestImportDate(from: "hr_records")
            
            // Track users per application and division
            var usersPerApplication: [String: Set<String>] = [:]
            var applicationsWithFewUsers = Set<String>()
            var applicationsWithOneUser = Set<String>()
            var applicationsByDivision: [String: Set<String>] = [:]
            var totalUsersCount = 0
            
            // First pass: Group users by application and track division information
            var applicationDivisions: [String: Set<String>] = [:]
            
            for record in combinedRecords {
                // Only process records that match the selected OTAP values
                guard selectedOTAP.contains(record.otap) else { continue }
                
                if !record.applicationName.isEmpty && record.applicationName != "#N/A" {
                    // Track divisions for this application
                    if applicationDivisions[record.applicationName] == nil {
                        applicationDivisions[record.applicationName] = []
                    }
                    if let division = record.division {
                        applicationDivisions[record.applicationName]?.insert(division)
                        
                        // Track applications per division
                        if applicationsByDivision[division] == nil {
                            applicationsByDivision[division] = []
                        }
                        applicationsByDivision[division]?.insert(record.applicationName)
                    }
                    
                    // Track users for this application
                    if usersPerApplication[record.applicationName] == nil {
                        usersPerApplication[record.applicationName] = []
                    }
                    usersPerApplication[record.applicationName]?.insert(record.systemAccount)
                }
            }
            
            // Calculate most used applications for selected division
            var mostUsedApps: [(name: String, userCount: Int)] = []
            if selectedDivision != "All" {
                // Create a map of applications to users only from the selected division
                var divisionUsersPerApp: [String: Set<String>] = [:]
                
                for record in combinedRecords {
                    guard selectedOTAP.contains(record.otap) else { continue }
                    guard record.division == selectedDivision else { continue }
                    
                    if !record.applicationName.isEmpty && record.applicationName != "#N/A" {
                        if divisionUsersPerApp[record.applicationName] == nil {
                            divisionUsersPerApp[record.applicationName] = []
                        }
                        divisionUsersPerApp[record.applicationName]?.insert(record.systemAccount)
                    }
                }
                
                // Sort applications by user count within the division
                let divisionApps = divisionUsersPerApp.map { appName, users in
                    (name: appName, userCount: users.count)
                }.sorted { $0.userCount > $1.userCount }
                
                // Calculate total users in division
                totalUsersCount = divisionApps.reduce(0) { $0 + $1.userCount }
                
                // Find applications accounting for 80% of users
                var runningSum = 0
                let threshold = Double(totalUsersCount) * 0.8
                
                for app in divisionApps {
                    runningSum += app.userCount
                    mostUsedApps.append(app)
                    if Double(runningSum) >= threshold {
                        break
                    }
                }
            }
            
            // Calculate division counts
            let divisionCounts = applicationsByDivision.map { (division: $0.key, count: $0.value.count) }
                .sorted { $0.count > $1.count }
            let totalApps = divisionCounts.reduce(0) { $0 + $1.count }
            
            // Second pass: Filter applications based on division and count users
            for (appName, users) in usersPerApplication {
                // Check if application belongs to selected division
                if selectedDivision != "All" {
                    let divisionSet = applicationDivisions[appName] ?? Set<String>()
                    if !divisionSet.contains(selectedDivision) {
                        continue
                    }
                }
                
                // Count users and categorize applications
                if users.count < 5 {
                    applicationsWithFewUsers.insert(appName)
                }
                if users.count == 1 {
                    applicationsWithOneUser.insert(appName)
                }
            }
            
            // Track applications per user and find users without applications
            var applicationsPerUser: [String: Set<String>] = [:]
            var usersWithFewApps = Set<String>()
            var usersWithoutApps = Set<String>()
            var allUsers = Set<String>()

            for record in combinedRecords {
                // Only process records that match the selected OTAP values
                guard selectedOTAP.contains(record.otap) else { continue }
                
                // Apply division filter if not "All"
                if selectedDivision != "All" && record.division != selectedDivision {
                    continue
                }

                // Track all users
                allUsers.insert(record.systemAccount)

                // Track applications per user
                if !record.applicationName.isEmpty && record.applicationName != "#N/A" {
                    if applicationsPerUser[record.systemAccount] == nil {
                        applicationsPerUser[record.systemAccount] = []
                    }
                    applicationsPerUser[record.systemAccount]?.insert(record.applicationName)
                }
            }

            // Find users with 1-5 applications and users without applications
            for user in allUsers {
                let appCount = applicationsPerUser[user]?.count ?? 0
                if appCount == 0 {
                    usersWithoutApps.insert(user)
                } else if appCount > 0 && appCount <= 5 {
                    usersWithFewApps.insert(user)
                }
            }

            await MainActor.run {
                lastADImportDate = adImportDate
                lastHRImportDate = hrImportDate
                self.applicationsWithFewUsers = applicationsWithFewUsers
                self.applicationsWithOneUser = applicationsWithOneUser
                self.usersWithFewApps = usersWithFewApps
                self.usersWithoutApps = usersWithoutApps
                self.divisionCounts = divisionCounts
                self.totalApplicationCount = totalApps
                self.mostUsedApplications = mostUsedApps
                self.totalUsers = totalUsersCount
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    BaselineApplicationsUsageView()
} 