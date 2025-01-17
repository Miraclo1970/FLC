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
        "Ready to start",
        "Planned",
        "Executed",
        "Aftercare OK",
        "Decharge"
    ]
    
    // Basic validation to ensure required fields are not empty
    var validationErrors: [String] {
        var errors: [String] = []
        
        let trimmedDepartment = department.trimmingCharacters(in: .whitespaces)
        
        if trimmedDepartment.isEmpty {
            errors.append("Department is required")
        }
        
        // Validate readiness value if provided
        if let readiness = migrationClusterReadiness?.trimmingCharacters(in: .whitespaces),
           !readiness.isEmpty,
           !ClusterData.allowedMigrationReadinessValues.contains(readiness) {
            errors.append("Invalid Migration Cluster Readiness value: '\(readiness)'. Allowed values are: \(ClusterData.allowedMigrationReadinessValues.sorted().joined(separator: ", "))")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(department: String, departmentSimple: String? = nil, domain: String? = nil, migrationCluster: String? = nil, migrationClusterReadiness: String? = nil) {
        self.id = UUID()
        
        // Normalize values: replace "N/A" with nil and trim whitespace
        let normalizeValue: (String?) -> String? = { value in
            guard let value = value else { return nil }
            if value == "N/A" { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        self.department = department == "N/A" ? "" : department.trimmingCharacters(in: .whitespaces)
        self.departmentSimple = normalizeValue(departmentSimple)
        self.domain = normalizeValue(domain)
        self.migrationCluster = normalizeValue(migrationCluster)
        self.migrationClusterReadiness = normalizeValue(migrationClusterReadiness)
        
        print("\nCreating ClusterData:")
        print("- Department: '\(self.department)'")
        print("- Department Simple: '\(self.departmentSimple ?? "nil")'")
        print("- Domain: '\(self.domain ?? "nil")'")
        print("- Migration Cluster: '\(self.migrationCluster ?? "nil")'")
        print("- Migration Cluster Readiness: '\(self.migrationClusterReadiness ?? "nil")'")
    }
} 