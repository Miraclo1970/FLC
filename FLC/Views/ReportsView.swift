import SwiftUI
import Charts

struct ReportsView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @StateObject private var reportManager = ReportManager()
    @State private var selectedReport: ReportType = .departmentApplications
    @State private var searchText = ""
    @State private var selectedDomain: String?
    @State private var selectedSuite: String?
    
    enum ReportType {
        case departmentApplications
        case migrationStatus
        case packageStatus
        case databaseExport
        
        var title: String {
            switch self {
            case .departmentApplications:
                return "Department Application Usage"
            case .migrationStatus:
                return "Migration Status by Department"
            case .packageStatus:
                return "Package Status Overview"
            case .databaseExport:
                return "Database Export"
            }
        }
        
        var icon: String {
            switch self {
            case .departmentApplications:
                return "rectangle.grid.2x2"
            case .migrationStatus:
                return "arrow.triangle.branch"
            case .packageStatus:
                return "shippingbox"
            case .databaseExport:
                return "square.and.arrow.down"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Report Type Selector
            HStack {
                Text("Reports Dashboard")
                    .font(.title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Export Button
                Button(action: exportCurrentReport) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // Report Selection Tabs
            HStack(spacing: 20) {
                ForEach([ReportType.departmentApplications, .migrationStatus, .packageStatus], id: \.self) { type in
                    ReportTabButton(
                        title: type.title,
                        icon: type.icon,
                        isSelected: selectedReport == type
                    ) {
                        selectedReport = type
                    }
                }
            }
            .padding()
            
            // Filters
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search departments or applications...", text: $searchText)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Domain Filter
                Picker("Domain", selection: $selectedDomain) {
                    Text("All Domains").tag(String?.none)
                    ForEach(Array(reportManager.availableDomains), id: \.self) { domain in
                        Text(domain).tag(Optional(domain))
                    }
                }
                .labelsHidden()
                
                // Suite Filter
                Picker("Suite", selection: $selectedSuite) {
                    Text("All Suites").tag(String?.none)
                    ForEach(Array(reportManager.availableSuites), id: \.self) { suite in
                        Text(suite).tag(Optional(suite))
                    }
                }
                .labelsHidden()
            }
            .padding(.horizontal)
            
            // Report Content
            ScrollView {
                switch selectedReport {
                case .departmentApplications:
                    DepartmentApplicationsReport(
                        reportManager: reportManager,
                        searchText: searchText,
                        selectedDomain: selectedDomain,
                        selectedSuite: selectedSuite
                    )
                case .migrationStatus:
                    MigrationStatusReport(searchText: searchText, selectedDomain: selectedDomain)
                case .packageStatus:
                    PackageStatusReport(searchText: searchText, selectedDomain: selectedDomain)
                case .databaseExport:
                    Text("Please use the Export menu in the sidebar for database exports")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await reportManager.generateReports(from: databaseManager)
            }
        }
    }
    
    private func exportCurrentReport() {
        // Will implement export functionality
    }
}

struct ReportTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
    }
}

struct DepartmentApplicationsReport: View {
    let reportManager: ReportManager
    let searchText: String
    let selectedDomain: String?
    let selectedSuite: String?
    
    private var filteredReports: [DepartmentApplicationReport] {
        reportManager.filteredReports(
            searchText: searchText,
            domain: selectedDomain,
            suite: selectedSuite
        )
    }
    
    private var chartData: [DepartmentApplicationChartData] {
        filteredReports.map { report in
            let activeCount = report.applications.filter { $0.status == .active }.count
            let pendingCount = report.applications.filter { $0.status == .pending }.count
            let retiredCount = report.applications.filter { $0.status == .retired }.count
            
            return DepartmentApplicationChartData(
                department: report.department,
                applicationCount: report.totalApplications,
                activeCount: activeCount,
                pendingCount: pendingCount,
                retiredCount: retiredCount
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Cards
            HStack(spacing: 20) {
                ReportCard(
                    title: "Total Departments",
                    value: "\(reportManager.totalDepartments)",
                    icon: "building.2"
                )
                ReportCard(
                    title: "Total Applications",
                    value: "\(reportManager.totalApplications)",
                    icon: "app.badge"
                )
                ReportCard(
                    title: "Active Domains",
                    value: "\(reportManager.totalDomains)",
                    icon: "network"
                )
            }
            
            // Main Chart
            VStack(alignment: .leading) {
                Text("Application Distribution by Department")
                    .font(.headline)
                
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Department", data.department),
                        y: .value("Applications", data.applicationCount)
                    )
                    .foregroundStyle(by: .value("Status", "Total"))
                    
                    BarMark(
                        x: .value("Department", data.department),
                        y: .value("Applications", data.activeCount)
                    )
                    .foregroundStyle(by: .value("Status", "Active"))
                    
                    BarMark(
                        x: .value("Department", data.department),
                        y: .value("Applications", data.pendingCount)
                    )
                    .foregroundStyle(by: .value("Status", "Pending"))
                    
                    BarMark(
                        x: .value("Department", data.department),
                        y: .value("Applications", data.retiredCount)
                    )
                    .foregroundStyle(by: .value("Status", "Retired"))
                }
                .frame(height: 300)
                .chartForegroundStyleScale([
                    "Total": Color.gray.opacity(0.3),
                    "Active": Color.green,
                    "Pending": Color.orange,
                    "Retired": Color.red
                ])
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Detailed List
            VStack(alignment: .leading) {
                Text("Detailed Overview")
                    .font(.headline)
                
                ForEach(filteredReports) { report in
                    DepartmentApplicationRow(report: report)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct DepartmentApplicationRow: View {
    let report: DepartmentApplicationReport
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading) {
                        Text(report.department)
                            .fontWeight(.semibold)
                        Text(report.domain)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(report.totalApplications) Applications")
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.applications) { app in
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading) {
                                Text(app.name)
                                Text(app.suite)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                StatusBadge(text: app.status.rawValue, type: .status(app.status))
                                StatusBadge(text: app.migrationReadiness.rawValue, type: .migration(app.migrationReadiness))
                            }
                        }
                        .padding(.leading)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct StatusBadge: View {
    let text: String
    let type: BadgeType
    
    enum BadgeType {
        case status(ApplicationUsage.ApplicationStatus)
        case migration(ApplicationUsage.MigrationReadiness)
        
        var color: Color {
            switch self {
            case .status(let status):
                switch status {
                case .active: return .green
                case .pending: return .orange
                case .retired: return .red
                }
            case .migration(let readiness):
                switch readiness {
                case .notStarted: return .red
                case .inProgress: return .orange
                case .completed: return .green
                case .notRequired: return .gray
                }
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(type.color.opacity(0.2))
            .foregroundColor(type.color)
            .cornerRadius(4)
    }
}

struct MigrationStatusReport: View {
    let searchText: String
    let selectedDomain: String?
    
    var body: some View {
        Text("Migration Status Report - Coming Soon")
            .foregroundColor(.secondary)
    }
}

struct PackageStatusReport: View {
    let searchText: String
    let selectedDomain: String?
    
    var body: some View {
        Text("Package Status Report - Coming Soon")
            .foregroundColor(.secondary)
    }
}

struct ReportCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ChartPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [5]))
            
            Text("Chart will be implemented here")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ReportsView()
} 