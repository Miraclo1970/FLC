import Foundation
import GRDB

// Database record structure for migration data
struct MigrationRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let applicationName: String
    let applicationSuiteNew: String
    let willBe: String
    let inScopeOutScopeDivision: String
    let migrationPlatform: String
    let migrationApplicationReadiness: String
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "migration_records"
    
    // Explicitly define the columns for GRDB
    enum Columns {
        static let id = Column("id")
        static let applicationName = Column("applicationName")
        static let applicationSuiteNew = Column("applicationSuiteNew")
        static let willBe = Column("willBe")
        static let inScopeOutScopeDivision = Column("inScopeOutScopeDivision")
        static let migrationPlatform = Column("migrationPlatform")
        static let migrationApplicationReadiness = Column("migrationApplicationReadiness")
        static let importDate = Column("importDate")
        static let importSet = Column("importSet")
    }
    
    // Define persistence behavior
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.applicationName] = applicationName
        container[Columns.applicationSuiteNew] = applicationSuiteNew
        container[Columns.willBe] = willBe
        container[Columns.inScopeOutScopeDivision] = inScopeOutScopeDivision
        container[Columns.migrationPlatform] = migrationPlatform
        container[Columns.migrationApplicationReadiness] = migrationApplicationReadiness
        container[Columns.importDate] = importDate
        container[Columns.importSet] = importSet
    }
    
    init(from data: MigrationData) {
        self.id = nil
        self.applicationName = data.applicationName
        self.applicationSuiteNew = data.applicationSuiteNew
        self.willBe = data.willBe
        self.inScopeOutScopeDivision = data.inScopeOutScopeDivision
        self.migrationPlatform = data.migrationPlatform
        self.migrationApplicationReadiness = data.migrationApplicationReadiness
        self.importDate = Date()
        
        // Create a descriptive import set identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "Migration_Import_\(dateFormatter.string(from: Date()))"
    }
}

// Migration data structure with basic validation
// Only records with non-empty required fields will be imported into the database
struct MigrationData: Identifiable, Codable {
    let id: UUID
    let applicationName: String
    let applicationSuiteNew: String
    let willBe: String
    let inScopeOutScopeDivision: String
    let migrationPlatform: String
    let migrationApplicationReadiness: String
    
    // Basic validation to ensure required fields are not empty
    // Records that don't pass validation will be skipped during import
    var validationErrors: [String] {
        var errors: [String] = []
        
        if applicationName.isEmpty {
            errors.append("Application Name is required")
        }
        
        if applicationSuiteNew.isEmpty {
            errors.append("Application Suite New is required")
        }
        
        if willBe.isEmpty {
            errors.append("Will be is required")
        }
        
        if inScopeOutScopeDivision.isEmpty {
            errors.append("In scope/out scope Division is required")
        }
        
        if migrationPlatform.isEmpty {
            errors.append("Migration Platform is required")
        }
        
        if migrationApplicationReadiness.isEmpty {
            errors.append("Migration Application Readiness is required")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(applicationName: String, applicationSuiteNew: String, willBe: String, inScopeOutScopeDivision: String, migrationPlatform: String, migrationApplicationReadiness: String) {
        self.id = UUID()
        self.applicationName = applicationName
        self.applicationSuiteNew = applicationSuiteNew
        self.willBe = willBe
        self.inScopeOutScopeDivision = inScopeOutScopeDivision
        self.migrationPlatform = migrationPlatform
        self.migrationApplicationReadiness = migrationApplicationReadiness
    }
} 