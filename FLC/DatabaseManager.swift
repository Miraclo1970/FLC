import Foundation
import GRDB

// User record structure
struct User: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let username: String
    let password: String
    let userType: String
    
    // Define the table name
    static let databaseTableName = "users"
}

// AD record structure for database
struct ADRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let adGroup: String
    let systemAccount: String
    let applicationName: String
    let applicationSuite: String
    let otap: String
    let critical: String
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "ad_records"
    
    init(from data: ADData) {
        self.id = nil
        self.adGroup = data.adGroup
        self.systemAccount = data.systemAccount
        self.applicationName = data.applicationName
        self.applicationSuite = data.applicationSuite
        self.otap = data.otap
        self.critical = data.critical
        self.importDate = Date()
        
        // Create a more descriptive import set identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "AD_Import_\(dateFormatter.string(from: Date()))"
    }
}

// HR record structure for database
struct HRRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let systemAccount: String
    let department: String?
    let jobRole: String?
    let division: String?
    let leaveDate: Date?
    let employeeNumber: String?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "hr_records"
    
    init(from data: HRData) {
        self.id = nil
        self.systemAccount = data.systemAccount
        self.department = data.department
        self.jobRole = data.jobRole
        self.division = data.division
        self.leaveDate = data.leaveDate
        self.employeeNumber = data.employeeNumber
        self.importDate = Date()
        
        // Create a more descriptive import set identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "HR_Import_\(dateFormatter.string(from: Date()))"
    }
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbPool: DatabasePool?
    
    private init() {
        do {
            try setupDatabase()
        } catch {
            print("Critical error during database initialization: \(error)")
            // In a real app, you might want to show an error UI to the user
        }
    }
    
    private func setupDatabase() throws {
        // Get the documents directory path
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = documentsPath.appendingPathComponent("flc_database.sqlite")
        
        print("Database path: \(dbPath.path)")
        
        // If database exists and we need to recreate it
        if fileManager.fileExists(atPath: dbPath.path) {
            try? fileManager.removeItem(at: dbPath)
            print("Removed existing database to recreate with new schema")
        }
        
        // Create database pool
        dbPool = try DatabasePool(path: dbPath.path)
        
        // Create tables
        try createTables()
        
        // Seed initial data
        try seedInitialData()
    }
    
    private func createTables() throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try dbPool.write { db in
            // Create users table
            try db.create(table: "users", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("username", .text).notNull().unique()
                t.column("password", .text).notNull()
                t.column("userType", .text).notNull()
            }
            
            // Create AD records table
            try db.create(table: "ad_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("adGroup", .text).notNull()
                t.column("systemAccount", .text).notNull()
                t.column("applicationName", .text).notNull()
                t.column("applicationSuite", .text).notNull()
                t.column("otap", .text).notNull()
                t.column("critical", .text).notNull()
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()  // Added import set column
                t.uniqueKey(["adGroup", "systemAccount"])
            }
            
            // Create HR records table
            try db.create(table: "hr_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("systemAccount", .text).notNull().unique()
                t.column("department", .text)
                t.column("jobRole", .text)
                t.column("division", .text)
                t.column("leaveDate", .datetime)
                t.column("employeeNumber", .text)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()  // Added import set column
            }
        }
        print("Tables created successfully")
    }
    
    // Save AD records to database with upsert behavior
    func saveADRecords(_ records: [ADData]) async throws -> (saved: Int, skipped: Int) {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.write { db -> (Int, Int) in
            var counts = (saved: 0, skipped: 0)
            
            for record in records {
                let dbRecord = ADRecord(from: record)
                
                // Try to find existing record by composite key (adGroup + systemAccount)
                if let existingRecord = try ADRecord
                    .filter(Column("adGroup") == record.adGroup)
                    .filter(Column("systemAccount") == record.systemAccount)
                    .fetchOne(db) {
                    // Update existing record with new data, preserving id
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                    counts.saved += 1
                } else {
                    // Insert new record
                    try dbRecord.insert(db)
                    counts.saved += 1
                }
            }
            
            return counts
        }
    }
    
    // Save HR records to database with upsert behavior
    func saveHRRecords(_ records: [HRData]) async throws -> (saved: Int, skipped: Int) {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.write { db -> (Int, Int) in
            var counts = (saved: 0, skipped: 0)
            
            for record in records {
                let dbRecord = HRRecord(from: record)
                
                // Try to find existing record by systemAccount
                if let existingRecord = try HRRecord.filter(Column("systemAccount") == record.systemAccount).fetchOne(db) {
                    // Update existing record with new data, preserving systemAccount and id
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                    counts.saved += 1
                } else {
                    // Insert new record
                    try dbRecord.insert(db)
                    counts.saved += 1
                }
            }
            
            return counts
        }
    }
    
    // Fetch AD records with pagination
    func fetchADRecords(limit: Int = 1000, offset: Int = 0) async throws -> [ADRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            try ADRecord
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // Fetch all HR records
    func fetchHRRecords() async throws -> [HRRecord] {
        try await dbPool?.read { db in
            try HRRecord.fetchAll(db)
        } ?? []
    }
    
    func seedInitialData() throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try dbPool.write { db in
            // Only seed if no users exist
            let count = try User.fetchCount(db)
            guard count == 0 else {
                print("Database already contains users, skipping seed")
                return
            }
            
            // Create default users
            let users = [
                User(username: "admin", password: "admin123", userType: "admin"),
                User(username: "manager", password: "manager123", userType: "manager"),
                User(username: "user", password: "user123", userType: "user")
            ]
            
            for user in users {
                try user.insert(db)
                print("Created user: \(user.username) with type: \(user.userType)")
            }
        }
    }
    
    public func ensureInitialData() {
        do {
            try seedInitialData()
        } catch {
            print("Error seeding initial data: \(error)")
        }
    }
    
    func validateUser(username: String, password: String) -> (success: Bool, userType: String?) {
        do {
            guard let dbPool = dbPool else {
                print("No database connection")
                return (false, nil)
            }
            
            print("Attempting to validate user: \(username)")
            
            // Special case for admin - no password required
            if username == "admin" {
                return (true, "admin")
            }
            
            // For other users, check both username and password
            let user = try dbPool.read { db in
                try User.filter(Column("username") == username)
                    .filter(Column("password") == password)
                    .fetchOne(db)
            }
            
            if let user = user {
                print("User found: \(user.username) with type: \(user.userType)")
                return (true, user.userType)
            }
            
            print("Invalid credentials for user: \(username)")
            return (false, nil)
            
        } catch {
            print("Validate user error: \(error)")
            return (false, nil)
        }
    }
    
    func listAllUsers() {
        do {
            guard let dbPool = dbPool else { return }
            
            let users = try dbPool.read { db in
                try User.fetchAll(db)
            }
            
            print("\n=== Current Users ===")
            for user in users {
                print("Username: \(user.username), Type: \(user.userType)")
            }
            print("===================\n")
        } catch {
            print("Error listing users: \(error)")
        }
    }
    
    // Delete AD record
    func deleteADRecord(_ record: ADRecord) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try record.delete(db)
        }
    }
    
    // Delete HR record
    func deleteHRRecord(_ record: HRRecord) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try record.delete(db)
        }
    }
    
    // Clear all AD records
    func clearADRecords() async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try db.execute(sql: "DELETE FROM ad_records")
        }
    }
    
    // Clear all HR records
    func clearHRRecords() async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try db.execute(sql: "DELETE FROM hr_records")
        }
    }
} 