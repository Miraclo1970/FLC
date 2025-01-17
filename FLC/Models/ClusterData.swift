import Foundation
import GRDB

// Database record structure for cluster data
struct ClusterRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let department: String
    let departmentSimple: String?
    let domain: String?
    let migrationCluster: String?
    let migrationClusterReadiness: String?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "cluster_records"
    
    // Explicitly define the columns for GRDB
    enum Columns {
        static let id = Column("id")
        static let department = Column("department")
        static let departmentSimple = Column("departmentSimple")
        static let domain = Column("domain")
        static let migrationCluster = Column("migrationCluster")
        static let migrationClusterReadiness = Column("migrationClusterReadiness")
        static let importDate = Column("importDate")
        static let importSet = Column("importSet")
    }
    
    // Define persistence behavior
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.department] = department
        container[Columns.departmentSimple] = departmentSimple
        container[Columns.domain] = domain
        container[Columns.migrationCluster] = migrationCluster
        container[Columns.migrationClusterReadiness] = migrationClusterReadiness
        container[Columns.importDate] = importDate
        container[Columns.importSet] = importSet
    }
    
    init(from data: ClusterData) {
        self.id = nil
        self.department = data.department
        self.departmentSimple = data.departmentSimple
        self.domain = data.domain
        self.migrationCluster = data.migrationCluster
        self.migrationClusterReadiness = data.migrationClusterReadiness
        self.importDate = Date()
        
        // Create a descriptive import set identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "Cluster_Import_\(dateFormatter.string(from: Date()))"
    }
}

// Cluster data structure with basic validation
struct ClusterData: Identifiable, Codable {
    let id: UUID
    let department: String
    let departmentSimple: String?
    let domain: String?
    let migrationCluster: String?
    let migrationClusterReadiness: String?
    
    // Define allowed migration readiness values
    static let allowedMigrationReadinessValues: Set<String> = [
        "",
        "Orderlist to Dep",
        "Orderlist Confirmed",
        "Waiting for Apps",
        "On Hold",
        "Ready to Start",
        "Planned",
        "Executed",
        "Aftercare OK",
        "Decharge"
    ]
    
    // Basic validation to ensure required fields are not empty
    var validationErrors: [String] {
        var errors: [String] = []
        
        if department.isEmpty {
            errors.append("Department is required")
        }
        if migrationCluster?.isEmpty ?? true {
            errors.append("Migration Cluster is required")
        }
        if let readiness = migrationClusterReadiness,
           !readiness.isEmpty,
           !ClusterData.allowedMigrationReadinessValues.contains(readiness) {
            errors.append("Invalid Migration Cluster Readiness value: '\(readiness)'. Allowed values are: \(ClusterData.allowedMigrationReadinessValues.sorted().joined(separator: ", "))")
        }
        
        // Validate Migration Cluster Readiness if provided
        if let readiness = migrationClusterReadiness {
            let validStatuses = [
                "orderlist to dep",
                "orderlist confirmed",
                "waiting for apps",
                "on hold",
                "ready to start",
                "planned",
                "executed",
                "aftercare ok",
                "decharge"
            ]
            
            // If readiness is empty or N/A, that's fine - it's optional
            if readiness.isEmpty || readiness == "N/A" {
                // Do nothing, empty value is allowed
            } else {
                let normalizedReadiness = readiness.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !validStatuses.contains(normalizedReadiness) {
                    errors.append("Invalid Migration Cluster Readiness status: '\(readiness)'. Must be empty, 'N/A', or one of: \(validStatuses.joined(separator: ", "))")
                }
            }
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(department: String, departmentSimple: String? = nil, domain: String? = nil, migrationCluster: String? = nil, migrationClusterReadiness: String? = nil) {
        self.id = UUID()
        print("\nCreating ClusterData:")
        print("- Raw department: '\(department)'")
        print("- Raw departmentSimple: '\(departmentSimple ?? "nil")'")
        print("- Raw domain: '\(domain ?? "nil")'")
        print("- Raw migrationCluster: '\(migrationCluster ?? "nil")'")
        print("- Raw migrationClusterReadiness: '\(migrationClusterReadiness ?? "nil")'")
        
        // Store values, replacing "N/A" with empty string
        self.department = department == "N/A" ? "" : department
        self.departmentSimple = departmentSimple == "N/A" ? "" : departmentSimple
        self.domain = domain == "N/A" ? "" : domain
        self.migrationCluster = migrationCluster == "N/A" ? "" : migrationCluster
        self.migrationClusterReadiness = migrationClusterReadiness == "N/A" ? "" : migrationClusterReadiness?.trimmingCharacters(in: .whitespaces)
        
        print("Final values:")
        print("- Department: '\(self.department)'")
        print("- Department Simple: '\(self.departmentSimple ?? "nil")'")
        print("- Domain: '\(self.domain ?? "nil")'")
        print("- Migration Cluster: '\(self.migrationCluster ?? "nil")'")
        print("- Migration Cluster Readiness: '\(self.migrationClusterReadiness ?? "nil")'")
    }
} 