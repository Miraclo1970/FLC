import Foundation

struct DepartmentApplicationReport: Identifiable {
    let id = UUID()
    let department: String
    let domain: String
    let applications: [ApplicationUsage]
    
    var totalApplications: Int {
        applications.count
    }
}

struct ApplicationUsage: Identifiable {
    let id = UUID()
    let name: String
    let suite: String
    let status: ApplicationStatus
    let migrationReadiness: MigrationReadiness
    
    enum ApplicationStatus: String {
        case active = "Active"
        case pending = "Pending"
        case retired = "Retired"
    }
    
    enum MigrationReadiness: String {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case completed = "Completed"
        case notRequired = "Not Required"
    }
}

class ReportManager: ObservableObject {
    @Published var departmentReports: [DepartmentApplicationReport] = []
    @Published var availableDomains: Set<String> = []
    @Published var availableSuites: Set<String> = []
    
    // Statistics
    var totalDepartments: Int {
        Set(departmentReports.map { report in report.department }).count
    }
    
    var totalApplications: Int {
        Set(departmentReports.flatMap { report in
            report.applications.map { app in app.name }
        }).count
    }
    
    var totalDomains: Int {
        availableDomains.count
    }
    
    // Filtering
    func filteredReports(searchText: String, domain: String?, suite: String?) -> [DepartmentApplicationReport] {
        var filtered = departmentReports
        
        if !searchText.isEmpty {
            filtered = filtered.filter { report in
                report.department.localizedCaseInsensitiveContains(searchText) ||
                report.applications.contains { app in
                    app.name.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        if let domain = domain {
            filtered = filtered.filter { $0.domain == domain }
        }
        
        if let suite = suite {
            filtered = filtered.filter { report in
                report.applications.contains { app in
                    app.suite == suite
                }
            }
        }
        
        return filtered
    }
    
    // Data Generation
    @MainActor
    func generateReports(from databaseManager: DatabaseManager) async {
        // Clear existing data
        departmentReports = []
        availableDomains = []
        availableSuites = []
        
        // Get cluster records for application information
        guard let clusterRecords = try? await databaseManager.fetchClusterRecords() else { return }
        
        // Process records and create reports
        let processedData = await processClusterRecords(clusterRecords)
        
        // Update published properties
        departmentReports = processedData.reports
        availableDomains = processedData.domains
        availableSuites = processedData.suites
    }
    
    private func processClusterRecords(_ records: [ClusterRecord]) async -> (reports: [DepartmentApplicationReport], domains: Set<String>, suites: Set<String>) {
        // Create a dictionary to group applications by department
        var departmentApplications: [String: (domain: String, apps: [ApplicationUsage])] = [:]
        var domains: Set<String> = []
        var suites: Set<String> = []
        
        // Process cluster records to get application information
        for cluster in records {
            let department = cluster.department
            let domain = cluster.domain ?? "Unknown"
            
            // Create or update application list for department
            if departmentApplications[department] == nil {
                departmentApplications[department] = (domain: domain, apps: [])
            }
            
            // Add application usage
            let app = ApplicationUsage(
                name: cluster.migrationCluster ?? "Unknown",
                suite: cluster.migrationClusterReadiness ?? "Unknown",
                status: determineStatus(from: cluster),
                migrationReadiness: determineMigrationReadiness(from: cluster)
            )
            
            departmentApplications[department]?.apps.append(app)
            
            // Update available domains and suites
            if !domain.isEmpty {
                domains.insert(domain)
            }
            if let suite = cluster.migrationClusterReadiness, !suite.isEmpty {
                suites.insert(suite)
            }
        }
        
        // Create department reports
        let reports = departmentApplications.map { department, info in
            DepartmentApplicationReport(
                department: department,
                domain: info.domain,
                applications: info.apps
            )
        }.sorted { $0.department < $1.department }
        
        return (reports: reports, domains: domains, suites: suites)
    }
    
    private func determineStatus(from cluster: ClusterRecord) -> ApplicationUsage.ApplicationStatus {
        // Implement logic to determine application status
        // This is a placeholder implementation
        if cluster.migrationClusterReadiness == "Completed" {
            return .active
        } else if cluster.migrationClusterReadiness == "Not Started" {
            return .pending
        } else {
            return .active
        }
    }
    
    private func determineMigrationReadiness(from cluster: ClusterRecord) -> ApplicationUsage.MigrationReadiness {
        // Convert cluster readiness to migration readiness
        switch cluster.migrationClusterReadiness {
        case "Not Started":
            return .notStarted
        case "In Progress":
            return .inProgress
        case "Completed":
            return .completed
        default:
            return .notRequired
        }
    }
}

// Chart Data Structures
struct DepartmentApplicationChartData: Identifiable {
    let id = UUID()
    let department: String
    let applicationCount: Int
    let activeCount: Int
    let pendingCount: Int
    let retiredCount: Int
} 