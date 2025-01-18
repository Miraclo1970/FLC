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
    
    // Define allowed migration readiness values with their canonical forms
    private static let migrationReadinessNormalizations: [String: String] = [
        "ready to start": "Ready to start",
        "planned": "Planned",
        "orderlist to dep": "Orderlist to dep",
        "orderlist confirmed": "Orderlist confirmed",
        "waiting for apps": "Waiting for apps",
        "on hold": "On hold",
        "executed": "Executed",
        "aftercare ok": "Aftercare ok",
        "decharge": "Decharge"
    ]
    
    // Basic validation to ensure required fields are not empty
    var validationErrors: [String] {
        var errors: [String] = []
        
        if department.isEmpty {
            errors.append("Department is required")
        }
        
        // Validate Migration Cluster Readiness if provided
        if let readiness = migrationClusterReadiness {
            let normalizedReadiness = readiness.trimmingCharacters(in: .whitespaces).lowercased()
            if !normalizedReadiness.isEmpty && !ClusterData.migrationReadinessNormalizations.keys.contains(normalizedReadiness) {
                errors.append("Invalid Migration Cluster Readiness value")
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
        
        // Store values, replacing "N/A" and empty strings with nil
        self.department = department == "N/A" ? "" : department
        self.departmentSimple = departmentSimple.flatMap { $0 == "N/A" || $0.isEmpty ? nil : $0 }
        self.domain = domain.flatMap { $0 == "N/A" || $0.isEmpty ? nil : $0 }
        self.migrationCluster = migrationCluster.flatMap { $0 == "N/A" || $0.isEmpty ? nil : $0 }
        
        // Special handling for migrationClusterReadiness to trim whitespace and normalize case
        self.migrationClusterReadiness = migrationClusterReadiness.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            if trimmed == "N/A" || trimmed.isEmpty {
                return nil
            }
            
            let normalizedInput = trimmed.lowercased()
            return ClusterData.migrationReadinessNormalizations[normalizedInput] ?? trimmed
        }
        
        print("Final values:")
        print("- Department: '\(self.department)'")
        print("- Department Simple: '\(self.departmentSimple ?? "nil")'")
        print("- Domain: '\(self.domain ?? "nil")'")
        print("- Migration Cluster: '\(self.migrationCluster ?? "nil")'")
        print("- Migration Cluster Readiness: '\(self.migrationClusterReadiness ?? "nil")'")
    }
} 