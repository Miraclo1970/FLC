import Foundation
import GRDB

// Migration data structure with validation
struct MigrationData: Identifiable, Codable {
    let id: UUID
    let applicationName: String      // Column A
    let applicationNew: String       // Column B
    let applicationSuiteNew: String  // Column C
    let willBe: String              // Column D
    let inScopeOutScopeDivision: String  // Column E
    let migrationPlatform: String    // Column F
    let migrationApplicationReadiness: String  // Column G
    
    // Normalize application name for comparison
    var normalizedApplicationName: String {
        return applicationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // Validation rules
    var validationErrors: [String] {
        var errors: [String] = []
        
        // Only required field is application name
        if applicationName.isEmpty || applicationName == "N/A" {
            errors.append("Application Name is required")
            return errors
        }
        
        // Check for duplicates
        if DatabaseManager.shared.isDuplicateMigrationApplication(normalizedApplicationName) {
            errors.append("Duplicate Application Name '\(applicationName)'")
        }
        
        // Only validate "Will be" if it's filled in and not N/A
        if !willBe.isEmpty && willBe != "N/A" {
            // Don't validate against AD records for now
            // if !DatabaseManager.shared.hasADApplication(willBe) {
            //     errors.append("Will be application '\(willBe)' not found in AD records")
            // }
        }
        
        // All other fields are accepted as-is
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(applicationName: String, 
         applicationNew: String = "N/A",
         applicationSuiteNew: String = "N/A",
         willBe: String = "N/A",
         inScopeOutScopeDivision: String = "N/A",
         migrationPlatform: String = "N/A",
         migrationApplicationReadiness: String = "N/A") {
        self.id = UUID()
        self.applicationName = applicationName
        self.applicationNew = applicationNew.isEmpty ? "N/A" : applicationNew
        self.applicationSuiteNew = applicationSuiteNew.isEmpty ? "N/A" : applicationSuiteNew
        self.willBe = willBe.isEmpty ? "N/A" : willBe
        self.inScopeOutScopeDivision = inScopeOutScopeDivision.isEmpty ? "N/A" : inScopeOutScopeDivision
        self.migrationPlatform = migrationPlatform.isEmpty ? "N/A" : migrationPlatform
        self.migrationApplicationReadiness = migrationApplicationReadiness.isEmpty ? "N/A" : migrationApplicationReadiness
    }
}

// Database record structure for migration data
struct MigrationRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let applicationName: String
    let applicationNew: String
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
        static let applicationNew = Column("applicationNew")
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
        container[Columns.applicationNew] = applicationNew
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
        self.applicationNew = data.applicationNew
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