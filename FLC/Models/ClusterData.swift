import Foundation
import GRDB

// Database record structure for cluster data
struct ClusterRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let department: String
    let departmentSimple: String
    let domain: String
    let migrationCluster: String
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
        container[Columns.importDate] = importDate
        container[Columns.importSet] = importSet
    }
    
    init(from data: ClusterData) {
        self.id = nil
        self.department = data.department
        self.departmentSimple = data.departmentSimple
        self.domain = data.domain
        self.migrationCluster = data.migrationCluster
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
    let departmentSimple: String
    let domain: String
    let migrationCluster: String
    
    // Basic validation to ensure required fields are not empty
    var validationErrors: [String] {
        var errors: [String] = []
        
        if department.isEmpty {
            errors.append("Department is required")
        }
        
        if departmentSimple.isEmpty {
            errors.append("Department Simple is required")
        }
        
        if domain.isEmpty {
            errors.append("Domain is required")
        }
        
        if migrationCluster.isEmpty {
            errors.append("Migration Cluster is required")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(department: String, departmentSimple: String, domain: String, migrationCluster: String) {
        self.id = UUID()
        self.department = department
        self.departmentSimple = departmentSimple
        self.domain = domain
        self.migrationCluster = migrationCluster
    }
} 