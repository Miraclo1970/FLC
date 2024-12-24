import SwiftUI
import GRDB

struct DivisionOverviewView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var divisions: [String] = []
    @State private var selectedDivision: String = ""
    @State private var records: [CombinedRecord] = []
    @State private var isLoading = true
    
    // Current date information
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
    private let currentDate = Date()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter
    }()
    
    // Computed properties for aggregated data
    private var departmentData: [(String, Int)] {
        let today = Date()
        let grouped = Dictionary(grouping: records.filter { record in 
            record.otap == "P" &&
            (record.leaveDate == nil || record.leaveDate! > today)
        }) { $0.departmentSimple ?? "Unknown" }
        return grouped.map { department, departmentRecords in
            // Get unique applications for this department
            let uniqueApps = Set(departmentRecords.map { $0.applicationName })
            return (department, uniqueApps.count)
        }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading data...")
            } else if divisions.isEmpty {
                Text("No divisions found")
                    .font(.title)
                    .foregroundColor(.gray)
            } else {
                TabView(selection: $selectedDivision) {
                    ForEach(divisions, id: \.self) { division in
                        DivisionTabView(
                            division: division,
                            records: records.filter { $0.division == division }
                        )
                        .tabItem {
                            Label(division, systemImage: "building.2")
                        }
                        .tag(division)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch all combined records
            records = try await databaseManager.fetchCombinedRecords()
            
            // Extract unique divisions
            divisions = Array(Set(records.compactMap { $0.division }))
                .filter { !$0.isEmpty }
                .sorted()
            
            if let firstDivision = divisions.first {
                selectedDivision = firstDivision
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
}

struct DivisionTabView: View {
    let division: String
    let records: [CombinedRecord]
    
    // Filter for production records only
    private var productionRecords: [CombinedRecord] {
        let today = Date()
        return records.filter { record in
            record.otap == "P" &&
            (record.leaveDate == nil || record.leaveDate! > today)
        }
    }
    
    // Group records by domain (production only)
    private var recordsByDomain: [String: [CombinedRecord]] {
        Dictionary(grouping: productionRecords) { $0.domain ?? "Unknown" }
    }
    
    // Count total unique users in the division (production only)
    private var totalUniqueUsers: Int {
        let uniqueAccounts = Set(productionRecords.map { $0.systemAccount })
        return uniqueAccounts.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header information
                HStack(spacing: 20) {
                    InfoCard(title: "Division", value: division)
                    InfoCard(title: "Department", value: "\(Set(productionRecords.compactMap { $0.departmentSimple }).count)")
                    InfoCard(title: "Total Users", value: "\(totalUniqueUsers)")
                    InfoCard(title: "OTAP", value: "P")
                }
                
                // Date information
                HStack(spacing: 20) {
                    InfoCard(title: "Year", value: "\(Calendar.current.component(.year, from: Date()))")
                    InfoCard(title: "Week", value: "\(Calendar.current.component(.weekOfYear, from: Date()))")
                    InfoCard(title: "Date", value: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))
                }
                
                // Domain sections
                ForEach(Array(recordsByDomain.keys).sorted(), id: \.self) { domain in
                    if let domainRecords = recordsByDomain[domain] {
                        DomainSection(domain: domain, records: domainRecords)
                    }
                }
            }
            .padding()
        }
    }
}

struct DomainSection: View {
    let domain: String
    let records: [CombinedRecord]
    
    // Computed property for department data
    private var departmentData: [(String, Int)] {
        let today = Date()
        let departments = Set(records.filter { record in
            record.otap == "P" &&
            (record.leaveDate == nil || record.leaveDate! > today)
        }.compactMap { $0.departmentSimple })
        
        return departments.map { department in
            let count = applicationCount(for: department)
            return (department, count)
        }.sorted { $0.0 < $1.0 }
    }
    
    // Helper function to get active production records for a department
    private func activeProductionRecords(for department: String) -> [CombinedRecord] {
        let today = Date()
        return records.filter { record in
            record.otap == "P" &&
            record.departmentSimple == department &&
            (record.leaveDate == nil || record.leaveDate! > today)
        }
    }
    
    private func uniqueUserCount(for department: String) -> Int {
        let departmentRecords = activeProductionRecords(for: department)
        let uniqueAccounts = Set(departmentRecords.map { $0.systemAccount })
        return uniqueAccounts.count
    }
    
    private func applicationCount(for department: String) -> Int {
        let departmentRecords = activeProductionRecords(for: department)
        let uniqueApps = Set(departmentRecords.map { $0.applicationName })
        return uniqueApps.count
    }
    
    private func packageStatusCount(for department: String) -> Int {
        let departmentRecords = activeProductionRecords(for: department)
        let appsWithStatus = departmentRecords.filter { record in
            record.applicationPackageStatus != nil &&
            record.applicationPackageStatus != "Ready for Testing"
        }
        let uniqueAppsWithStatus = Set(appsWithStatus.map { $0.applicationName })
        return uniqueAppsWithStatus.count
    }
    
    private func readyForTestingCount(for department: String) -> Int {
        let departmentRecords = activeProductionRecords(for: department)
        let appsReadyForTesting = departmentRecords.filter { record in
            record.applicationPackageStatus == "Ready for Testing"
        }
        let uniqueAppsReady = Set(appsReadyForTesting.map { $0.applicationName })
        return uniqueAppsReady.count
    }
    
    private func testingStatusCount(for department: String) -> Int {
        let departmentRecords = activeProductionRecords(for: department)
        let appsInTesting = departmentRecords.filter { record in
            record.applicationTestStatus != nil &&
            record.applicationTestStatus != "Ready for Migration"
        }
        let uniqueAppsInTesting = Set(appsInTesting.map { $0.applicationName })
        return uniqueAppsInTesting.count
    }
    
    private func readyForMigrationCount(for department: String) -> Int {
        let departmentRecords = activeProductionRecords(for: department)
        let appsReadyForMigration = departmentRecords.filter { record in
            record.applicationTestStatus == "Ready for Migration"
        }
        let uniqueAppsReady = Set(appsReadyForMigration.map { $0.applicationName })
        return uniqueAppsReady.count
    }
    
    private func clusterInfo(for department: String) -> String {
        if let record = activeProductionRecords(for: department).first {
            return record.migrationCluster ?? "N/A"
        }
        return "N/A"
    }
    
    private func clusterReadinessPercentage(for department: String) -> Double {
        let departmentRecords = activeProductionRecords(for: department)
        let uniqueApps = Set(departmentRecords.map { $0.applicationName })
        guard !uniqueApps.isEmpty else { return 0.0 }
        
        let readyApps = Set(departmentRecords.filter { record in
            record.migrationReadiness == "Ready"
        }.map { $0.applicationName })
        
        return Double(readyApps.count) / Double(uniqueApps.count) * 100.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(domain)
                .font(.headline)
                .padding(.vertical, 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        HeaderCell("Department Simple", isWide: true)
                        HeaderCell("Users")
                        HeaderCell("Applications")
                        HeaderCell("Package Status")
                        HeaderCell("Ready for Testing")
                        HeaderCell("Testing Status")
                        HeaderCell("Ready for Migration")
                        HeaderCell("Cluster")
                        HeaderCell("Cluster Readiness")
                    }
                    
                    // Data rows
                    ForEach(Array(departmentData.enumerated()), id: \.1.0) { index, data in
                        let (department, _) = data
                        HStack(spacing: 0) {
                            DataCell(department, isWide: true)
                            DataCell("\(uniqueUserCount(for: department))")
                            DataCell("\(applicationCount(for: department))")
                            DataCell("\(packageStatusCount(for: department))")
                            DataCell("\(readyForTestingCount(for: department))")
                            DataCell("\(testingStatusCount(for: department))")
                            DataCell("\(readyForMigrationCount(for: department))")
                            DataCell(clusterInfo(for: department))
                            ProgressCell(value: clusterReadinessPercentage(for: department))
                        }
                        .background(index % 2 == 0 ? Color.white.opacity(0.05) : Color.blue.opacity(0.02))
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ProgressCell: View {
    let value: Double
    
    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 6)
                
                // Progress dot
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .offset(x: (value / 100.0) * 74)  // 80 - dot size = 74
            }
            
            Text(String(format: "%.0f%%", value))
                .font(.system(size: 11))
                .frame(width: 30, alignment: .trailing)
        }
        .frame(width: 120, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct HeaderCell: View {
    let text: String
    let isWide: Bool
    
    init(_ text: String, isWide: Bool = false) {
        self.text = text
        self.isWide = isWide
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .frame(width: isWide ? 300 : 120, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.05))
    }
}

struct DataCell: View {
    let text: String
    let isWide: Bool
    
    init(_ text: String, isWide: Bool = false) {
        self.text = text
        self.isWide = isWide
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .frame(width: isWide ? 300 : 120, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(width: 150)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.1)))
    }
} 