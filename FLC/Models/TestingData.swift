import Foundation
import GRDB

// Database record structure for test data
struct TestRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let applicationName: String
    let testStatus: String
    let testDate: Date
    let testResult: String
    let testComments: String?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "test_records"
    
    // Explicitly define the columns for GRDB
    enum Columns {
        static let id = Column("id")
        static let applicationName = Column("applicationName")
        static let testStatus = Column("testStatus")
        static let testDate = Column("testDate")
        static let testResult = Column("testResult")
        static let testComments = Column("testComments")
        static let importDate = Column("importDate")
        static let importSet = Column("importSet")
    }
    
    // Define persistence behavior
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.applicationName] = applicationName
        container[Columns.testStatus] = testStatus
        container[Columns.testDate] = testDate
        container[Columns.testResult] = testResult
        container[Columns.testComments] = testComments
        container[Columns.importDate] = importDate
        container[Columns.importSet] = importSet
    }
    
    init(from data: TestingData) {
        self.id = nil
        self.applicationName = data.applicationName
        self.testStatus = data.testStatus
        self.testDate = data.testDate
        self.testResult = data.testResult
        self.testComments = data.testComments
        self.importDate = Date()
        
        // Create a descriptive import set identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "Test_Import_\(dateFormatter.string(from: Date()))"
    }
}

// Test data structure with basic validation
// Only records with non-empty required fields will be imported into the database
struct TestingData: Identifiable, Codable {
    let id: UUID
    let applicationName: String
    let testStatus: String
    let testDate: Date
    let testResult: String
    let testComments: String?
    
    // Basic validation to ensure required fields are not empty
    // Records that don't pass validation will be skipped during import
    var validationErrors: [String] {
        var errors: [String] = []
        
        if applicationName.isEmpty {
            errors.append("Application Name is required")
        }
        
        if testStatus.isEmpty {
            errors.append("Test Status is required")
        }
        
        if testResult.isEmpty {
            errors.append("Test Result is required")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    init(applicationName: String, testStatus: String, testDate: Date, testResult: String, testComments: String? = nil) {
        self.id = UUID()
        self.applicationName = applicationName
        self.testStatus = testStatus
        self.testDate = testDate
        self.testResult = testResult
        self.testComments = testComments
    }
} 