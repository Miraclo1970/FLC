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
    
    // Basic validation to ensure required fields are not empty
    var validationErrors: [String] {
        var errors: [String] = []
        
        if department.isEmpty {
            errors.append("Department is required")
        }
        
        // Validate Migration Cluster Readiness if provided
        if let readiness = migrationClusterReadiness, !readiness.isEmpty, readiness != "N/A" {
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
            
            let normalizedReadiness = readiness.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !validStatuses.contains(normalizedReadiness) {
                errors.append("Invalid Migration Cluster Readiness status: '\(readiness)'. Valid values are: \(validStatuses.joined(separator: ", "))")
            }
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
        self.migrationClusterReadiness = migrationClusterReadiness == "N/A" ? "" : migrationClusterReadiness
    }
} 