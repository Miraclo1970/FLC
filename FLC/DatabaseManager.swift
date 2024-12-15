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

// Package status record structure for database
struct PackageRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    let systemAccount: String
    let applicationName: String
    let packageStatus: String
    let packageReadinessDate: Date?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "package_status_records"
    
    init(from data: PackageStatusData) {
        self.id = data.id
        self.systemAccount = data.systemAccount
        self.applicationName = data.applicationName
        self.packageStatus = data.packageStatus
        self.packageReadinessDate = data.packageReadinessDate
        self.importDate = data.importDate
        self.importSet = data.importSet
    }
}

class DatabaseManager {
    public static let shared: DatabaseManager = DatabaseManager()
    private var dbPool: DatabasePool?
    private let currentVersion = 3  // Incremented version for test_records table
    
    private init() {
        do {
            try setupDatabase()
        } catch {
            print("Critical error during database initialization: \(error)")
        }
    }
    
    private func setupDatabase() throws {
        let dbPath = "FLC.db"
        
        // Create or open database
        dbPool = try DatabasePool(path: dbPath)
        
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try dbPool.write { db in
            // Create users table
            try db.create(table: "users", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("username", .text).notNull().unique()
                t.column("password", .text).notNull()
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
                t.column("importSet", .text).notNull()
                // Create a unique index on the combination of adGroup and systemAccount
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
                t.column("importSet", .text).notNull()
            }
            
            // Create combined records table
            try db.create(table: "combined_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                // AD fields
                t.column("adGroup", .text).notNull()
                t.column("systemAccount", .text).notNull()
                t.column("applicationName", .text).notNull()
                t.column("applicationSuite", .text).notNull()
                t.column("otap", .text).notNull()
                t.column("critical", .text).notNull()
                // HR fields
                t.column("department", .text)
                t.column("jobRole", .text)
                t.column("division", .text)
                t.column("leaveDate", .datetime)
                t.column("employeeNumber", .text)
                // Package tracking fields
                t.column("applicationPackageStatus", .text)
                t.column("applicationPackageReadinessDate", .datetime)
                // Test tracking fields
                t.column("applicationTestStatus", .text)
                t.column("applicationTestReadinessDate", .datetime)
                // Department and Migration fields
                t.column("departmentSimple", .text)
                t.column("migrationCluster", .text)
                t.column("migrationReadiness", .text)
                // Metadata
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on the combination of adGroup and systemAccount
                t.uniqueKey(["adGroup", "systemAccount"])
            }
            
            // Create package status records table
            try db.create(table: "package_status_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("systemAccount", .text)
                t.column("applicationName", .text).notNull()
                t.column("packageStatus", .text).notNull()
                t.column("packageReadinessDate", .datetime)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on applicationName only since systemAccount is not used
                t.uniqueKey(["applicationName"])
            }
            
            // Create test_records table
            try db.create(table: "test_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("applicationName", .text).notNull()
                t.column("testStatus", .text).notNull()
                t.column("testDate", .date).notNull()
                t.column("testResult", .text).notNull()
                t.column("testComments", .text)
                t.column("importDate", .date).notNull()
                t.column("importSet", .text).notNull()
                t.uniqueKey(["applicationName", "importSet"])
            }
        }
        print("Database setup completed successfully")
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
    
    // Save package status records to database with upsert behavior
    func savePackageRecords(_ records: [PackageStatusData]) async throws -> (saved: Int, skipped: Int) {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        print("Attempting to save \(records.count) package status records")
        
        return try await dbPool.write { db -> (Int, Int) in
            var counts = (saved: 0, skipped: 0)
            
            for record in records {
                let dbRecord = PackageRecord(from: record)
                print("Processing package record for application: \(dbRecord.applicationName)")
                
                // Try to find existing record by applicationName only
                if let existingRecord = try PackageRecord
                    .filter(Column("applicationName") == record.applicationName)
                    .fetchOne(db) {
                    print("Found existing record for \(dbRecord.applicationName), updating...")
                    // Update existing record with new data, preserving id
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                    counts.saved += 1
                } else {
                    print("No existing record for \(dbRecord.applicationName), inserting new record...")
                    // Insert new record
                    try dbRecord.insert(db)
                    counts.saved += 1
                }
            }
            
            print("Finished saving package records - Saved: \(counts.saved), Skipped: \(counts.skipped)")
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
    
    // Fetch package status records with pagination
    func fetchPackageRecords(limit: Int = 1000, offset: Int = 0) async throws -> [PackageRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            try PackageRecord
                .order(sql: "applicationName ASC")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
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
    
    // Clear all package status records
    func clearPackageRecords() async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try db.execute(sql: "DELETE FROM package_status_records")
        }
    }
    
    // Fetch combined records with pagination
    func fetchCombinedRecords(limit: Int = 1000, offset: Int = 0) async throws -> [CombinedRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            try CombinedRecord
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // Generate combined records from AD and HR data
    func generateCombinedRecords() async throws -> Int {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.write { db -> Int in
            // First, clear existing combined records
            try db.execute(sql: "DELETE FROM combined_records")
            
            // Fetch all AD records, HR records, and Package Status records
            let adRecords = try ADRecord.fetchAll(db)
            let hrRecords = try HRRecord.fetchAll(db)
            let packageRecords = try PackageRecord.fetchAll(db)
            let testRecords = try TestRecord.fetchAll(db)
            
            print("Fetched \(adRecords.count) AD records, \(hrRecords.count) HR records, \(packageRecords.count) package status records, and \(testRecords.count) test records")
            
            // Create dictionaries for faster lookup
            let hrBySystemAccount = Dictionary(
                uniqueKeysWithValues: hrRecords.map { ($0.systemAccount, $0) }
            )
            let packageByAppName = Dictionary(
                uniqueKeysWithValues: packageRecords.map { ($0.applicationName, $0) }
            )
            let testByAppName = Dictionary(
                uniqueKeysWithValues: testRecords.map { ($0.applicationName, $0) }
            )
            
            var combinedCount = 0
            
            // For each AD record, create a combined record with HR and Package Status data if available
            for adRecord in adRecords {
                // Find matching HR record
                let hrRecord = hrBySystemAccount[adRecord.systemAccount]
                
                // Find matching Package Status record
                let packageRecord = packageByAppName[adRecord.applicationName]
                
                // Find matching Test record
                let testRecord = testByAppName[adRecord.applicationName]
                
                // Create combined record with optional HR, Package Status, and Test data
                let combinedRecord = CombinedRecord(
                    id: nil,
                    adGroup: adRecord.adGroup,
                    systemAccount: adRecord.systemAccount,
                    applicationName: adRecord.applicationName,
                    applicationSuite: adRecord.applicationSuite,
                    otap: adRecord.otap,
                    critical: adRecord.critical,
                    department: hrRecord?.department,
                    jobRole: hrRecord?.jobRole,
                    division: hrRecord?.division,
                    leaveDate: hrRecord?.leaveDate,
                    employeeNumber: hrRecord?.employeeNumber,
                    applicationPackageStatus: packageRecord?.packageStatus,
                    applicationPackageReadinessDate: packageRecord?.packageReadinessDate,
                    applicationTestStatus: testRecord?.testStatus,
                    applicationTestReadinessDate: testRecord?.testDate,
                    departmentSimple: nil,
                    migrationCluster: nil,
                    migrationReadiness: nil,
                    importDate: Date(),
                    importSet: "Combined_\(DateFormatter.hrDateFormatter.string(from: Date()))"
                )
                
                // Insert the combined record
                try combinedRecord.insert(db)
                combinedCount += 1
                
                // Print progress every 10000 records
                if combinedCount % 10000 == 0 {
                    print("Processed \(combinedCount) combined records...")
                }
            }
            
            print("Generated \(combinedCount) combined records from \(adRecords.count) AD records, \(hrRecords.count) HR records, \(packageRecords.count) package status records, and \(testRecords.count) test records")
            return combinedCount
        }
    }
    
    // Clear all combined records
    func clearCombinedRecords() async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try db.execute(sql: "DELETE FROM combined_records")
        }
    }
    
    // Query execution methods
    func executeQuery(dataType: ImportProgress.DataType, 
                     field: String, 
                     operator: String, 
                     value: String) async throws -> [Any] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        // First get the database state
        try await debugPrintRecords()
        
        return try await dbPool.read { db in
            // Build the SQL query based on data type
            let tableName: String
            switch dataType {
            case .ad:
                tableName = "ad_records"
            case .hr:
                tableName = "hr_records"
            case .combined:
                tableName = "combined_records"
            case .packageStatus:
                tableName = "package_status_records"
            case .testing:
                tableName = "test_records"
            }
            
            // Convert field name to database column name
            let columnName = field.lowercased().replacingOccurrences(of: " ", with: "_")
            
            // Map display field names to actual database column names
            let mappedColumnName: String
            switch columnName {
            case "job_role":
                mappedColumnName = "jobrole"
            case "system_account":
                mappedColumnName = "systemaccount"
            case "ad_group":
                mappedColumnName = "adgroup"
            case "application_name":
                mappedColumnName = "applicationname"
            case "application_suite":
                mappedColumnName = "applicationsuite"
            case "employee_number":
                mappedColumnName = "employeenumber"
            case "leave_date":
                mappedColumnName = "leavedate"
            case "package_status":
                mappedColumnName = "packagestatus"
            case "package_readiness_date":
                mappedColumnName = "packagereadinessdate"
            case "test_status":
                mappedColumnName = "teststatus"
            case "test_date":
                mappedColumnName = "testdate"
            case "test_result":
                mappedColumnName = "testresult"
            case "test_comments":
                mappedColumnName = "testcomments"
            default:
                mappedColumnName = columnName
            }
            
            // Build the WHERE clause based on operator
            let whereClause: String
            let arguments: StatementArguments
            
            switch `operator` {
            case "equals":
                whereClause = "\(mappedColumnName) = ?"
                arguments = [value]
            case "not equals":
                whereClause = "\(mappedColumnName) != ?"
                arguments = [value]
            case "contains":
                whereClause = "\(mappedColumnName) LIKE ?"
                arguments = ["%\(value)%"]
            case "not contains":
                whereClause = "\(mappedColumnName) NOT LIKE ?"
                arguments = ["%\(value)%"]
            case "starts with":
                whereClause = "\(mappedColumnName) LIKE ?"
                arguments = ["\(value)%"]
            case "ends with":
                whereClause = "\(mappedColumnName) LIKE ?"
                arguments = ["%\(value)"]
            case "is empty":
                whereClause = "(\(mappedColumnName) IS NULL OR \(mappedColumnName) = '')"
                arguments = []
            case "is not empty":
                whereClause = "(\(mappedColumnName) IS NOT NULL AND \(mappedColumnName) != '')"
                arguments = []
            case "before":
                // Parse date string to Date object
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                if let date = dateFormatter.date(from: value) {
                    whereClause = "\(mappedColumnName) < ?"
                    arguments = [date]
                } else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
                }
            case "after":
                // Parse date string to Date object
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                if let date = dateFormatter.date(from: value) {
                    whereClause = "\(mappedColumnName) > ?"
                    arguments = [date]
                } else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
                }
            default:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid operator"])
            }
            
            // Execute the query with proper type casting
            let sql = """
                SELECT * FROM \(tableName)
                WHERE \(whereClause)
                LIMIT 1000
                """
            
            print("Executing SQL: \(sql) with arguments: \(arguments)")
            
            switch dataType {
            case .ad:
                let adResults = try ADRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(adResults.count) AD records")
                return adResults as [Any]
            case .hr:
                let hrResults = try HRRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(hrResults.count) HR records")
                return hrResults as [Any]
            case .combined:
                let combinedResults = try CombinedRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(combinedResults.count) combined records")
                return combinedResults as [Any]
            case .packageStatus:
                let packageResults = try PackageRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(packageResults.count) package status records")
                return packageResults as [Any]
            case .testing:
                let testResults = try TestRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(testResults.count) test records")
                return testResults as [Any]
            }
        }
    }
    
    // Debug function to check database contents
    func debugPrintRecords() async throws {
        guard let dbPool = dbPool else { return }
        
        try await dbPool.read { db in
            print("\n=== Database Contents ===")
            
            // Check AD records
            let adCount = try ADRecord.fetchCount(db)
            let adSample = try ADRecord.limit(5).fetchAll(db)
            print("AD Records count: \(adCount)")
            print("Sample AD records:")
            for record in adSample {
                print("System Account: \(record.systemAccount)")
            }
            
            // Check HR records
            let hrCount = try HRRecord.fetchCount(db)
            let hrSample = try HRRecord.limit(5).fetchAll(db)
            print("\nHR Records count: \(hrCount)")
            print("Sample HR records:")
            for record in hrSample {
                print("System Account: \(record.systemAccount)")
            }
            
            // Check Combined records
            let combinedCount = try CombinedRecord.fetchCount(db)
            let combinedSample = try CombinedRecord.limit(5).fetchAll(db)
            print("\nCombined Records count: \(combinedCount)")
            print("Sample Combined records:")
            for record in combinedSample {
                print("System Account: \(record.systemAccount), AD Group: \(record.adGroup)")
            }
            
            print("=====================\n")
        }
    }
    
    // Individual field update methods for combined records
    
    // Package tracking updates
    func updatePackageStatus(forSystemAccount: String, adGroup: String, status: String) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationPackageStatus = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [status, forSystemAccount, adGroup]
            )
        }
    }
    
    func updatePackageReadinessDate(forSystemAccount: String, adGroup: String, date: Date) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationPackageReadinessDate = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [date, forSystemAccount, adGroup]
            )
        }
    }
    
    // Test tracking updates
    func updateTestStatus(forSystemAccount: String, adGroup: String, status: String) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationTestStatus = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [status, forSystemAccount, adGroup]
            )
        }
    }
    
    func updateTestReadinessDate(forSystemAccount: String, adGroup: String, date: Date) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationTestReadinessDate = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [date, forSystemAccount, adGroup]
            )
        }
    }
    
    // Department and Migration updates
    func updateDepartmentSimple(forSystemAccount: String, adGroup: String, department: String) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET departmentSimple = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [department, forSystemAccount, adGroup]
            )
        }
    }
    
    func updateMigrationCluster(forSystemAccount: String, adGroup: String, cluster: String) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET migrationCluster = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [cluster, forSystemAccount, adGroup]
            )
        }
    }
    
    func updateMigrationReadiness(forSystemAccount: String, adGroup: String, readiness: String) async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET migrationReadiness = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [readiness, forSystemAccount, adGroup]
            )
        }
    }
    
    // Verification method to check if a record exists before updating
    private func verifyRecordExists(systemAccount: String, adGroup: String, db: Database) throws -> Bool {
        let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM combined_records
            WHERE systemAccount = ? AND adGroup = ?
            """,
            arguments: [systemAccount, adGroup]
        ) ?? 0
        return count > 0
    }
    
    // Check database tables and contents
    func checkDatabaseState() async throws -> String {
        guard let dbPool = dbPool else {
            return "No database connection"
        }
        
        return try await dbPool.read { db in
            var report = "\n=== Database State ===\n"
            
            // Check tables exist
            let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
            report += "Tables in database: \(tables.joined(separator: ", "))\n\n"
            
            // Count records in each table
            let adCount = try ADRecord.fetchCount(db)
            let hrCount = try HRRecord.fetchCount(db)
            let combinedCount = try CombinedRecord.fetchCount(db)
            let packageCount = try PackageRecord.fetchCount(db)
            let userCount = try User.fetchCount(db)
            
            report += "Record counts:\n"
            report += "- Users: \(userCount)\n"
            report += "- AD Records: \(adCount)\n"
            report += "- HR Records: \(hrCount)\n"
            report += "- Combined Records: \(combinedCount)\n"
            report += "- Package Status Records: \(packageCount)\n"
            
            // Sample data from each table
            if adCount > 0 {
                let sample = try ADRecord.limit(1).fetchOne(db)
                report += "\nSample AD Record: \(sample?.systemAccount ?? "none")\n"
            }
            
            if hrCount > 0 {
                let sample = try HRRecord.limit(1).fetchOne(db)
                report += "Sample HR Record: \(sample?.systemAccount ?? "none")\n"
            }
            
            if combinedCount > 0 {
                let sample = try CombinedRecord.limit(1).fetchOne(db)
                report += "Sample Combined Record: \(sample?.systemAccount ?? "none")\n"
            }
            
            if packageCount > 0 {
                let sample = try PackageRecord.limit(1).fetchOne(db)
                report += "Sample Package Record: \(sample?.applicationName ?? "none")\n"
            }
            
            report += "===================\n"
            return report
        }
    }
    
    // Generate package records from combined records
    func generatePackageRecords() async throws -> Int {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        print("Starting package records generation from combined records")
        
        return try await dbPool.write { db -> Int in
            // Get all combined records
            let combinedRecords = try CombinedRecord.fetchAll(db)
            var packageCount = 0
            
            print("Found \(combinedRecords.count) combined records to process")
            
            // Create package records from combined records
            for record in combinedRecords {
                if let packageStatus = record.applicationPackageStatus {
                    print("Processing combined record for \(record.applicationName) with status: \(packageStatus)")
                    
                    let packageStatusData = PackageStatusData(
                        id: nil,
                        systemAccount: record.systemAccount,
                        applicationName: record.applicationName,
                        packageStatus: packageStatus,
                        packageReadinessDate: record.applicationPackageReadinessDate,
                        importDate: Date(),
                        importSet: "Generated_\(DateFormatter.hrDateFormatter.string(from: Date()))"
                    )
                    
                    // Try to find existing record
                    if let existingRecord = try PackageRecord
                        .filter(Column("applicationName") == record.applicationName)
                        .fetchOne(db) {
                        print("Updating existing package record for \(record.applicationName)")
                        var updatedRecord = PackageRecord(from: packageStatusData)
                        updatedRecord.id = existingRecord.id
                        try updatedRecord.update(db)
                    } else {
                        print("Creating new package record for \(record.applicationName)")
                        let packageRecord = PackageRecord(from: packageStatusData)
                        try packageRecord.insert(db)
                    }
                    packageCount += 1
                }
            }
            
            print("Generated \(packageCount) package records from \(combinedRecords.count) combined records")
            return packageCount
        }
    }
    
    // Save test records to database with upsert behavior
    func saveTestRecords(_ records: [TestingData]) async throws -> (saved: Int, skipped: Int) {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        print("Attempting to save \(records.count) test records")
        
        return try await dbPool.write { db -> (Int, Int) in
            var counts = (saved: 0, skipped: 0)
            
            for record in records {
                let dbRecord = TestRecord(from: record)
                print("Processing test record for application: \(dbRecord.applicationName)")
                
                // Try to find existing record by applicationName only
                if let existingRecord = try TestRecord
                    .filter(Column("applicationName") == record.applicationName)
                    .fetchOne(db) {
                    print("Found existing record for \(dbRecord.applicationName), updating...")
                    // Update existing record with new data, preserving id
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                    counts.saved += 1
                } else {
                    print("No existing record for \(dbRecord.applicationName), inserting new record...")
                    // Insert new record
                    try dbRecord.insert(db)
                    counts.saved += 1
                }
            }
            
            print("Finished saving test records - Saved: \(counts.saved), Skipped: \(counts.skipped)")
            return counts
        }
    }
    
    // Fetch test records with pagination
    func fetchTestRecords(limit: Int = 1000, offset: Int = 0) async throws -> [TestRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            try TestRecord
                .order(sql: "applicationName ASC")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // Clear all test records
    func clearTestRecords() async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        _ = try await dbPool.write { db in
            try db.execute(sql: "DELETE FROM test_records")
        }
    }
    
    // Generate test records from combined records
    func generateTestRecords() async throws -> Int {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        print("Starting test records generation from combined records")
        
        return try await dbPool.write { db -> Int in
            // Get all combined records
            let combinedRecords = try CombinedRecord.fetchAll(db)
            var testCount = 0
            
            print("Found \(combinedRecords.count) combined records to process")
            
            // Create test records from combined records
            for record in combinedRecords {
                if let testStatus = record.applicationTestStatus {
                    print("Processing combined record for \(record.applicationName) with status: \(testStatus)")
                    
                    let testingData = TestingData(
                        applicationName: record.applicationName,
                        testStatus: testStatus,
                        testDate: record.applicationTestReadinessDate ?? Date(),
                        testResult: "Pending",
                        testComments: nil
                    )
                    
                    let testRecord = TestRecord(from: testingData)
                    
                    // Try to find existing record
                    if let existingRecord = try TestRecord
                        .filter(Column("applicationName") == record.applicationName)
                        .fetchOne(db) {
                        print("Updating existing test record for \(record.applicationName)")
                        var updatedRecord = testRecord
                        updatedRecord.id = existingRecord.id
                        try updatedRecord.update(db)
                    } else {
                        print("Creating new test record for \(record.applicationName)")
                        try testRecord.insert(db)
                    }
                    testCount += 1
                }
            }
            
            print("Generated \(testCount) test records from \(combinedRecords.count) combined records")
            return testCount
        }
    }
} 