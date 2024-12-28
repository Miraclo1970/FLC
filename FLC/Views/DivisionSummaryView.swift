import SwiftUI
import GRDB
import UniformTypeIdentifiers

struct DivisionTabContent: View {
    let division: String
    @State private var departmentStats: [(
        department: String,
        migrationCluster: String?,
        applicationCount: Int,
        userCount: Int,
        packageProgress: Double,
        testingProgress: Double
    )] = []
    
    private var averageApplicationReadiness: String {
        let validStats = departmentStats.filter { stat in
            stat.applicationCount > 0
        }
        
        if validStats.isEmpty {
            return "0%"
        }
        
        let totalPackageProgress = validStats.reduce(0.0) { $0 + $1.packageProgress * Double($1.applicationCount) }
        let totalTestingProgress = validStats.reduce(0.0) { $0 + $1.testingProgress * Double($1.applicationCount) }
        let totalApps = Double(validStats.reduce(0) { $0 + $1.applicationCount })
        
        let avgProgress = ((totalPackageProgress + totalTestingProgress) / (2 * totalApps)) * 100
        return "\(Int(avgProgress))%"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Totals header
            Text("Totals")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            
            // Totals row
            HStack(spacing: 10) {
                Text("")
                    .frame(width: 200, alignment: .leading)
                Text("")
                    .frame(width: 150, alignment: .leading)
                Text("\(departmentStats.reduce(0) { $0 + $1.applicationCount })")
                    .frame(width: 80, alignment: .trailing)
                Text("\(departmentStats.reduce(0) { $0 + $1.userCount })")
                    .frame(width: 80, alignment: .trailing)
                VStack(alignment: .leading) {
                    let avgPackageProgress = departmentStats.isEmpty ? 0.0 : departmentStats.reduce(0.0) { $0 + $1.packageProgress } / Double(departmentStats.count)
                    ProgressView(value: avgPackageProgress)
                        .frame(width: 130)
                    Text("\(Int(avgPackageProgress * 100))%")
                        .font(.caption)
                }
                .frame(width: 130)
                VStack(alignment: .leading) {
                    let avgTestingProgress = departmentStats.isEmpty ? 0.0 : departmentStats.reduce(0.0) { $0 + $1.testingProgress } / Double(departmentStats.count)
                    ProgressView(value: avgTestingProgress)
                        .frame(width: 130)
                    Text("\(Int(avgTestingProgress * 100))%")
                        .font(.caption)
                }
                .frame(width: 130)
                Text(averageApplicationReadiness)
                    .frame(width: 120, alignment: .center)
                    .foregroundColor(getApplicationReadinessColor(status: averageApplicationReadiness))
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            Divider()
            
            // Department header
            DepartmentHeader()
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Department rows
                    ForEach(departmentStats, id: \.department) { stat in
                        DepartmentRow(department: stat.department, migrationCluster: stat.migrationCluster, applicationCount: stat.applicationCount, userCount: stat.userCount, packageProgress: stat.packageProgress, testingProgress: stat.testingProgress)
                        Divider()
                    }
                }
            }
        }
        .task {
            await loadDepartmentStats()
        }
    }
    
    private func loadDepartmentStats() async {
        do {
            let stats = try await DatabaseManager.shared.getDepartmentStats(forDivision: division)
            departmentStats = stats
        } catch {
            print("Error loading department stats: \(error)")
        }
    }
}

struct DepartmentRow: View {
    let department: String
    let migrationCluster: String?
    let applicationCount: Int
    let userCount: Int
    let packageProgress: Double
    let testingProgress: Double
    
    var applicationReadiness: String {
        let packagePercentage = packageProgress * 100
        let testingPercentage = testingProgress * 100
        
        if packagePercentage == 100 && testingPercentage == 100 {
            return "Ready for Migration"
        } else if packagePercentage == 0 && testingPercentage == 0 {
            return "Not Started"
        } else {
            return "In Progress"
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Text(department)
                .frame(width: 200, alignment: .leading)
            Text(migrationCluster ?? "")
                .frame(width: 150, alignment: .leading)
            Text("\(applicationCount)")
                .frame(width: 80, alignment: .trailing)
            Text("\(userCount)")
                .frame(width: 80, alignment: .trailing)
            VStack(alignment: .leading) {
                ProgressView(value: packageProgress)
                    .frame(width: 130)
                Text("\(Int(packageProgress * 100))%")
                    .font(.caption)
            }
            .frame(width: 130)
            VStack(alignment: .leading) {
                ProgressView(value: testingProgress)
                    .frame(width: 130)
                Text("\(Int(testingProgress * 100))%")
                    .font(.caption)
            }
            .frame(width: 130)
            Text(applicationReadiness)
                .frame(width: 120, alignment: .center)
                .foregroundColor(getApplicationReadinessColor(status: applicationReadiness))
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

private func getApplicationReadinessColor(status: String) -> Color {
    if let percentage = Int(status.replacingOccurrences(of: "%", with: "")) {
        if percentage == 0 {
            return .gray
        } else if percentage == 100 {
            return .green
        } else {
            return .blue
        }
    }
    return .primary
}

struct DepartmentHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Department")
                .frame(width: 200, alignment: .leading)
            Text("Migration Cluster")
                .frame(width: 150, alignment: .leading)
            Text("# Apps")
                .frame(width: 80, alignment: .trailing)
            Text("Users")
                .frame(width: 80, alignment: .trailing)
            Text("Package progress")
                .frame(width: 130, alignment: .center)
            Text("Testing progress")
                .frame(width: 130, alignment: .center)
            Text("Application Readiness")
                .frame(width: 120, alignment: .center)
        }
        .padding(.horizontal)
        .font(.headline)
    }
}

struct DivisionSummaryView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var selectedDivision: String = ""
    @State private var divisions: [String] = []
    @State private var showingExporter = false
    @State private var csvData = ""
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Selection controls
            VStack {
                Text("Select Division")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    Text("Division:")
                        .frame(width: 100, alignment: .trailing)
                    Picker("Division", selection: $selectedDivision) {
                        Text("Select Division").tag("")
                        ForEach(divisions, id: \.self) { division in
                            Text(division).tag(division)
                        }
                    }
                    .frame(width: 200)
                    
                    Spacer()
                    
                    Text("Filters:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Generate") {
                        showContent = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedDivision.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content area
            ZStack {
                if showContent && !selectedDivision.isEmpty {
                    DivisionTabContent(division: selectedDivision)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
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
                .disabled(!showContent || selectedDivision.isEmpty)
            }
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Division Progress")
        .onAppear {
            loadDivisions()
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: CSVDocument(data: csvData.data(using: .utf8) ?? Data()),
            contentType: .commaSeparatedText,
            defaultFilename: "\(selectedDivision)_department_progress"
        ) { result in
            if case .success = result {
                print("Successfully exported CSV")
            }
        }
    }
    
    private func loadDivisions() {
        Task {
            do {
                let records = try await databaseManager.fetchCombinedRecords()
                await MainActor.run {
                    divisions = Array(Set(records.compactMap { $0.division }))
                        .filter { !$0.isEmpty }
                        .sorted()
                }
            } catch {
                print("Error loading divisions: \(error)")
            }
        }
    }
    
    private func generateCSVData() async -> String {
        do {
            let stats = try await DatabaseManager.shared.getDepartmentStats(forDivision: selectedDivision)
            
            // CSV header
            var csv = "Department,Migration Cluster,# Apps,Users,Package Progress,Testing Progress,Application Readiness\n"
            
            // Add department rows
            for stat in stats {
                let packageProgress = String(format: "%.1f%%", stat.packageProgress * 100)
                let testingProgress = String(format: "%.1f%%", stat.testingProgress * 100)
                
                // Calculate application readiness
                let applicationReadiness = if stat.packageProgress == 1.0 && stat.testingProgress == 1.0 {
                    "Ready for Migration"
                } else if stat.packageProgress == 1.0 && stat.testingProgress == 0.5 {
                    "Testing"
                } else if stat.packageProgress == 1.0 && stat.testingProgress == 0.0 {
                    "Waiting for Test"
                } else if stat.packageProgress == 0.5 && stat.testingProgress == 0.0 {
                    "Building"
                } else {
                    "Not Started"
                }
                
                csv += "\(stat.department),\(stat.migrationCluster ?? ""),\(stat.applicationCount),\(stat.userCount),\(packageProgress),\(testingProgress),\(applicationReadiness)\n"
            }
            
            return csv
        } catch {
            print("Error generating CSV data: \(error)")
            return ""
        }
    }
}

#Preview {
    DivisionSummaryView()
        .environmentObject(DatabaseManager.shared)
} 