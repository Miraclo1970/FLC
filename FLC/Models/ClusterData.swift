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
        self.departmentSimple = data.departmentSimple == "N/A" ? "" : data.departmentSimple
        self.domain = data.domain == "N/A" ? "" : data.domain
        self.migrationCluster = data.migrationCluster == "N/A" ? "" : data.migrationCluster
        self.migrationClusterReadiness = data.migrationClusterReadiness == "N/A" ? "" : data.migrationClusterReadiness
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
    
    // Define allowed migration readiness values and their progress percentages
    private static let readinessMapping: [(value: String, progress: Double)] = [
        ("", 0.0),
        ("Orderlist to Dep", 10.0),
        ("Orderlist Confirmed", 20.0),
        ("Waiting for Apps", 25.0),
        ("On Hold", 30.0),
        ("Ready to start", 50.0),
        ("Planned", 60.0),
        ("Executed", 90.0),
        ("Aftercare OK", 98.0),
        ("Decharge", 100.0)
    ]
    
    static var allowedMigrationReadinessValues: Set<String> {
        Set(readinessMapping.map { $0.value })
    }
    
    static func progressForReadiness(_ readiness: String?) -> Double {
        guard let readiness = readiness else { return 0.0 }
        return readinessMapping.first { $0.value == readiness }?.progress ?? 0.0
    }
    
    // Helper function to normalize readiness values
    private static func normalizeReadinessValue(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespaces)
        print("Normalizing readiness value: '\(value)' -> '\(normalized)'")
        print("Allowed values: \(allowedMigrationReadinessValues.sorted())")
        
        // Try to find a match ignoring case and whitespace
        let matchingValue = readinessMapping.first { mapping in
            let normalizedMapping = mapping.value.trimmingCharacters(in: .whitespaces)
            let isMatch = normalizedMapping.lowercased() == normalized.lowercased()
            print("Comparing '\(normalized.lowercased())' with '\(normalizedMapping.lowercased())': \(isMatch)")
            return isMatch
        }?.value
        
        print("Final normalized value: \(matchingValue ?? "nil")")
        return matchingValue
    }
    
    // Basic validation to ensure required fields are not empty
    var validationErrors: [String] {
        var errors: [String] = []
        
        if department.isEmpty {
            errors.append("Department is required")
        }
        if domain?.isEmpty ?? true {
            errors.append("Domain is required")
        }
        if migrationCluster?.isEmpty ?? true {
            errors.append("Migration Cluster is required")
        }
        if let readiness = migrationClusterReadiness,
           !readiness.isEmpty,
           !ClusterData.allowedMigrationReadinessValues.contains(readiness) {
            errors.append("Invalid Migration Cluster Readiness value: '\(readiness)'. Allowed values are: \(ClusterData.allowedMigrationReadinessValues.joined(separator: ", "))")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(department: String, departmentSimple: String? = nil, domain: String? = nil, migrationCluster: String? = nil, migrationClusterReadiness: String? = nil) {
        self.id = UUID()
        self.department = department
        self.departmentSimple = departmentSimple == "N/A" ? "" : departmentSimple
        self.domain = domain == "N/A" ? "" : domain
        self.migrationCluster = migrationCluster == "N/A" ? "" : migrationCluster
        
        // Temporarily accept any readiness value
        if let readiness = migrationClusterReadiness, readiness != "N/A" {
            print("DEBUG: Setting readiness value: '\(readiness)'")
            self.migrationClusterReadiness = readiness
        } else {
            self.migrationClusterReadiness = ""
        }
    }
} 