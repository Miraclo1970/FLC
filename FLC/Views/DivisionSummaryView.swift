import SwiftUI
import GRDB
import UniformTypeIdentifiers

struct DivisionTabContent: View {
    let division: String
    @State private var departmentStats: [(department: String, migrationCluster: String?, applicationCount: Int, userCount: Int, packageProgress: Double, testingProgress: Double)] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Department header
            HStack(spacing: 0) {
                Text("Department")
                    .frame(width: 300, alignment: .leading)
                Text("Migration Cluster")
                    .frame(width: 150, alignment: .leading)
                Text("# Apps")
                    .frame(width: 80, alignment: .center)
                Text("Users")
                    .frame(width: 80, alignment: .center)
                Text("Package progress")
                    .frame(width: 150, alignment: .center)
                Text("Testing progress")
                    .frame(width: 150, alignment: .center)
            }
            .font(.headline)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Department rows
                    ForEach(departmentStats, id: \.department) { stat in
                        DepartmentRow(stat: stat)
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
    let stat: (department: String, migrationCluster: String?, applicationCount: Int, userCount: Int, packageProgress: Double, testingProgress: Double)
    
    var body: some View {
        HStack(spacing: 0) {
            Text(stat.department)
                .frame(width: 300, alignment: .leading)
            Text(stat.migrationCluster ?? "-")
                .frame(width: 150, alignment: .leading)
            Text("\(stat.applicationCount)")
                .frame(width: 80, alignment: .center)
            Text("\(stat.userCount)")
                .frame(width: 80, alignment: .center)
            ProgressView(value: stat.packageProgress)
                .frame(width: 150)
            ProgressView(value: stat.testingProgress)
                .frame(width: 150)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
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
            var csv = "Department,Migration Cluster,# Apps,Users,Package Progress,Testing Progress\n"
            
            // Add department rows
            for stat in stats {
                let packageProgress = String(format: "%.1f%%", stat.packageProgress * 100)
                let testingProgress = String(format: "%.1f%%", stat.testingProgress * 100)
                
                csv += "\(stat.department),\(stat.migrationCluster ?? ""),\(stat.applicationCount),\(stat.userCount),\(packageProgress),\(testingProgress)\n"
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