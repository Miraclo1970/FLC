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
struct HRRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let systemAccount: String
    let department: String?
    let jobRole: String?
    let division: String?
    let leaveDate: Date?
    let departmentSimple: String?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "hr_records"
    
    enum Columns {
        static let id = Column("id")
        static let systemAccount = Column("systemAccount")
        static let department = Column("department")
        static let jobRole = Column("jobRole")
        static let division = Column("division")
        static let leaveDate = Column("leaveDate")
        static let departmentSimple = Column("departmentSimple")
        static let importDate = Column("importDate")
        static let importSet = Column("importSet")
    }
    
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .custom { key in
        switch key {
        case CodingKeys.systemAccount: return "systemAccount"
        case CodingKeys.jobRole: return "jobRole"
        case CodingKeys.leaveDate: return "leaveDate"
        case CodingKeys.departmentSimple: return "departmentSimple"
        case CodingKeys.importDate: return "importDate"
        case CodingKeys.importSet: return "importSet"
        default: return key.stringValue
        }
    }
    
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .custom { key in
        switch key {
        case "systemAccount": return CodingKeys.systemAccount
        case "jobRole": return CodingKeys.jobRole
        case "leaveDate": return CodingKeys.leaveDate
        case "departmentSimple": return CodingKeys.departmentSimple
        case "importDate": return CodingKeys.importDate
        case "importSet": return CodingKeys.importSet
        default: return CodingKeys(stringValue: key) ?? CodingKeys.id
        }
    }
    
    init(from data: HRData) {
        self.id = nil
        self.systemAccount = data.systemAccount
        self.department = data.department
        self.jobRole = data.jobRole
        self.division = data.division
        self.leaveDate = data.leaveDate
        self.departmentSimple = data.departmentSimple
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
    let applicationName: String
    let packageStatus: String
    let packageReadinessDate: Date?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "package_status_records"
    
    init(from data: PackageStatusData) {
        self.id = data.id
        self.applicationName = data.applicationName
        self.packageStatus = data.packageStatus
        self.packageReadinessDate = data.packageReadinessDate
        self.importDate = data.importDate
        self.importSet = data.importSet
    }
}

class DatabaseManager: ObservableObject {
    public static let shared: DatabaseManager = DatabaseManager()
    @Published private var dbPool: DatabasePool?
    private let currentVersion = 4  // Increment this to force schema update
    private let versionKey = "database_version"
    
    // Add fetch method for combined records
    func fetchAllRecords() async throws -> [CombinedRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            try CombinedRecord.fetchAll(db)
        }
    }
    
    private init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
            let dbFolderURL = appSupportURL.appendingPathComponent("FLC", isDirectory: true)
            try fileManager.createDirectory(at: dbFolderURL, withIntermediateDirectories: true)
            
            let dbURL = dbFolderURL.appendingPathComponent("database.sqlite")
            print("Database path: \(dbURL.path)")
            
            // Check if we need to delete the existing database due to version mismatch
            let defaults = UserDefaults.standard
            let savedVersion = defaults.integer(forKey: versionKey)
            if savedVersion < currentVersion {
                try? fileManager.removeItem(at: dbURL)
                defaults.set(currentVersion, forKey: versionKey)
            }
            
            dbPool = try DatabasePool(path: dbURL.path)
            try createTables()
        } catch {
            print("Database initialization error: \(error)")
        }
    }
    
    private func createTables() throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try dbPool.write { db in
            print("Starting database setup...")
            
            // Create users table if it doesn't exist
            try db.create(table: "users", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("username", .text).notNull().unique()
                t.column("password", .text).notNull()
                t.column("userType", .text).notNull()
            }
            
            // Create AD records table if it doesn't exist
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
            
            // Create HR records table if it doesn't exist
            try db.create(table: "hr_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("systemAccount", .text).notNull().unique()
                t.column("department", .text)
                t.column("jobRole", .text)
                t.column("division", .text)
                t.column("leaveDate", .datetime)
                t.column("departmentSimple", .text)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
            }
            
            // Create combined_records table if it doesn't exist
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
                // Package tracking fields
                t.column("applicationPackageStatus", .text)
                t.column("applicationPackageReadinessDate", .datetime)
                // Test tracking fields
                t.column("applicationTestStatus", .text)
                t.column("applicationTestReadinessDate", .datetime)
                t.column("testResult", .text)
                t.column("testingPlanDate", .datetime)
                // Migration fields
                t.column("applicationNew", .text)
                t.column("applicationSuiteNew", .text)
                t.column("willBe", .text)
                t.column("inScopeOutScopeDivision", .text)
                t.column("migrationPlatform", .text)
                t.column("migrationApplicationReadiness", .text)
                // Department and Migration fields
                t.column("departmentSimple", .text)
                t.column("domain", .text)
                t.column("migrationCluster", .text)
                t.column("migrationReadiness", .text)
                // Metadata
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on the combination of adGroup and systemAccount
                t.uniqueKey(["adGroup", "systemAccount"])
            }
            
            // Create package status records table if it doesn't exist
            try db.create(table: "package_status_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("applicationName", .text).notNull()
                t.column("packageStatus", .text).notNull()
                t.column("packageReadinessDate", .datetime)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on applicationName
                t.uniqueKey(["applicationName"])
            }
            
            // Create test_records table if it doesn't exist
            try db.create(table: "test_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("applicationName", .text).notNull()
                t.column("testStatus", .text).notNull()
                t.column("testDate", .datetime)
                t.column("testResult", .text).notNull()
                t.column("testingPlanDate", .datetime)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on applicationName
                t.uniqueKey(["applicationName"])
            }
            
            // Create migration_records table if it doesn't exist
            try db.create(table: "migration_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("applicationName", .text).notNull()  // Only applicationName is required
                t.column("applicationNew", .text)
                t.column("applicationSuiteNew", .text)
                t.column("willBe", .text)
                t.column("inScopeOutScopeDivision", .text)
                t.column("migrationPlatform", .text)
                t.column("migrationApplicationReadiness", .text)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on applicationName
                t.uniqueKey(["applicationName"])
            }
            
            // Create cluster_records table if it doesn't exist
            try db.create(table: "cluster_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("department", .text).notNull()
                t.column("departmentSimple", .text)
                t.column("domain", .text)
                t.column("migrationCluster", .text)
                t.column("migrationClusterReadiness", .text)
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
                // Create a unique index on department
                t.uniqueKey(["department"])
            }
            
            print("Database setup completed successfully")
        }
    }
    
    // Save AD records to database with upsert behavior
    func saveADRecords(_ records: [ADData]) async throws -> (saved: Int, skipped: Int) {
        try await performDatabaseOperation("Save AD Records", write: true) { db in
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
        try await performDatabaseOperation("Save HR Records", write: true) { db in
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
        try await performDatabaseOperation("Save Package Records", write: true) { db in
            var counts = (saved: 0, skipped: 0)
            
            for record in records {
                let dbRecord = PackageRecord(from: record)
                print("Processing package record for application: \(dbRecord.applicationName)")
                
                // First, save/update the package_status_records table
                if let existingRecord = try PackageRecord
                    .filter(Column("applicationName") == record.applicationName)
                    .fetchOne(db) {
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                } else {
                    try dbRecord.insert(db)
                }
                
                // Then update ALL matching records in combined_records table
                // This ensures consistency across all instances of the same application
                try db.execute(
                    sql: """
                        UPDATE combined_records
                        SET applicationPackageStatus = ?,
                            applicationPackageReadinessDate = ?
                        WHERE applicationName = ?
                        """,
                    arguments: [
                        record.packageStatus,
                        record.packageReadinessDate,
                        record.applicationName
                    ]
                )
                
                counts.saved += 1
                
                // Print progress every 100 records
                if counts.saved % 100 == 0 {
                    print("Processed \(counts.saved) package records...")
                }
            }
            
            return counts
        }
    }
    
    // Fetch AD records with pagination
    func fetchADRecords(limit: Int = 1000, offset: Int = 0) async throws -> [ADRecord] {
        try await performDatabaseOperation("Fetch AD Records", write: false) { db in
            try ADRecord
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // Fetch HR records
    func fetchHRRecords() async throws -> [HRRecord] {
        try await performDatabaseOperation("Fetch HR Records", write: false) { db in
            try HRRecord.fetchAll(db)
        }
    }
    
    // Fetch package status records with pagination
    func fetchPackageRecords(limit: Int = 1000, offset: Int = 0) async throws -> [PackageRecord] {
        try await performDatabaseOperation("Fetch Package Records", write: false) { db in
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
    
    @MainActor
    func validateUser(username: String, password: String) async throws -> (success: Bool, userType: String?) {
        try await performDatabaseOperation("Validate User") { db in
            // Special case for admin - no password required
            if username == "admin" {
                return (true, "admin")
            }
            
            let user = try User.filter(Column("username") == username)
                .filter(Column("password") == password)
                .fetchOne(db)
            
            return (user != nil, user?.userType)
        }
    }
    
    @MainActor
    func listAllUsers() async throws {
        _ = try await performDatabaseOperation("List Users", write: false) { db in
            let users = try User.fetchAll(db)
            
            print("\n=== Current Users ===")
            for user in users {
                print("Username: \(user.username), Type: \(user.userType)")
            }
            print("===================\n")
            return users  // Return the users array even though we're discarding it
        }
    }
    
    // Delete AD record
    func deleteADRecord(_ record: ADRecord) async throws {
        _ = try await performDatabaseOperation("Delete AD Record", write: true) { db in
            try record.delete(db)
            return true
        }
    }
    
    // Delete HR record
    func deleteHRRecord(_ record: HRRecord) async throws {
        _ = try await performDatabaseOperation("Delete HR Record", write: true) { db in
            try record.delete(db)
            return true
        }
    }
    
    // Clear all AD records
    func clearADRecords() async throws {
        _ = try await performDatabaseOperation("Clear AD Records", write: true) { db in
            try db.execute(sql: "DELETE FROM ad_records")
            try db.execute(sql: "DELETE FROM sqlite_sequence WHERE name='ad_records'")
            return true
        }
    }
    
    // Clear all HR records
    func clearHRRecords() async throws {
        _ = try await performDatabaseOperation("Clear HR Records", write: true) { db in
            try db.execute(sql: "DELETE FROM hr_records")
            try db.execute(sql: "DELETE FROM sqlite_sequence WHERE name='hr_records'")
            return true
        }
    }
    
    // Clear all package status records
    func clearPackageRecords() async throws {
        _ = try await performDatabaseOperation("Clear Package Records", write: true) { db in
            try db.execute(sql: "DELETE FROM package_status_records")
            try db.execute(sql: "DELETE FROM sqlite_sequence WHERE name='package_status_records'")
            return true
        }
    }
    
    // Clear all combined records
    func clearCombinedRecords() async throws {
        _ = try await performDatabaseOperation("Clear Combined Records", write: true) { db in
            try db.execute(sql: "DELETE FROM combined_records")
            try db.execute(sql: "DELETE FROM sqlite_sequence WHERE name='combined_records'")
            return true
        }
    }
    
    // Clear all test records
    func clearTestRecords() async throws {
        _ = try await performDatabaseOperation("Clear Test Records", write: true) { db in
            try db.execute(sql: "DELETE FROM test_records")
            try db.execute(sql: "DELETE FROM sqlite_sequence WHERE name='test_records'")
            return true
        }
    }
    
    // Fetch combined records without pagination
    func fetchCombinedRecords(limit: Int = 1000, offset: Int = 0) async throws -> [CombinedRecord] {
        try await performDatabaseOperation("Fetch Combined Records", write: false) { db in
            try CombinedRecord.fetchAll(db)  // Fetch all records without limit
        }
    }
    
    // Generate combined records from AD and HR data
    func generateCombinedRecords() async throws -> Int {
        try await performDatabaseOperation("Generate Combined Records", write: true) { db in
            // First, clear existing combined records
            try CombinedRecord.deleteAll(db)
            
            // Get all AD records
            let adRecords = try ADRecord.fetchAll(db)
            print("Processing \(adRecords.count) AD records")
            
            // Get all HR records for lookup
            let hrRecords = try HRRecord.fetchAll(db)
            print("Found \(hrRecords.count) HR records for matching")
            
            // Create dictionaries for faster lookups
            let hrLookup = Dictionary(uniqueKeysWithValues: hrRecords.map { ($0.systemAccount, $0) })
            let packageRecords = try PackageRecord.fetchAll(db)
            let packageLookup = Dictionary(uniqueKeysWithValues: packageRecords.map { ($0.applicationName, $0) })
            let testRecords = try TestRecord.fetchAll(db)
            let testLookup = Dictionary(uniqueKeysWithValues: testRecords.map { ($0.applicationName, $0) })
            let migrationRecords = try MigrationRecord.fetchAll(db)
            let migrationLookup = Dictionary(uniqueKeysWithValues: migrationRecords.map { ($0.applicationName, $0) })
            
            var combinedCount = 0
            
            // Process each AD record
            for adRecord in adRecords {
                let hrRecord = hrLookup[adRecord.systemAccount]
                let packageRecord = packageLookup[adRecord.applicationName]
                let testRecord = testLookup[adRecord.applicationName]
                let migrationRecord = migrationLookup[adRecord.applicationName]
                
                // Create combined record with optional fields
                let combinedRecord = CombinedRecord(
                    adRecord: adRecord,
                    hrRecord: hrRecord,
                    packageRecord: packageRecord,
                    testRecord: testRecord,
                    migrationRecord: migrationRecord,
                    importDate: Date(),
                    importSet: "Combined_\(DateFormatter.hrDateFormatter.string(from: Date()))"
                )
                
                // Insert new record
                try combinedRecord.insert(db)
                combinedCount += 1
                
                if combinedCount % 1000 == 0 {
                    print("Processed \(combinedCount) combined records...")
                }
            }
            
            print("Generated \(combinedCount) combined records")
            return combinedCount
        }
    }
    
    // Query execution methods
    func executeQuery(dataType: ImportProgress.DataType, 
                     field: String, 
                     operator: String, 
                     value: String) async throws -> [Any] {
        // First get the database state
        try await debugPrintRecords()
        
        return try await performDatabaseOperation("Execute Query", write: false) { db in
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
            case .migration:
                tableName = "migration_records"
            case .cluster:
                tableName = "cluster_records"
            }
            
            // Convert field name to database column name
            let columnName = field.lowercased().replacingOccurrences(of: " ", with: "_")
            
            // Map display field names to actual database column names
            let mappedColumnName: String
            switch columnName {
            case "job_role":
                mappedColumnName = "jobrole"
            case "system_account":
                // Only map systemAccount for tables that have this column
                switch dataType {
                case .testing:
                    mappedColumnName = columnName  // Keep original for test records
                default:
                    mappedColumnName = "systemaccount"
                }
            case "ad_group":
                mappedColumnName = "adgroup"
            case "application_name":
                mappedColumnName = "applicationname"
            case "application_suite":
                mappedColumnName = "applicationsuite"
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
            case "testing_plan_date":
                mappedColumnName = "testingPlanDate"
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
            case .migration:
                let migrationResults = try MigrationRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(migrationResults.count) migration records")
                return migrationResults as [Any]
            case .cluster:
                let clusterResults = try ClusterRecord.fetchAll(db, sql: sql, arguments: arguments)
                print("Found \(clusterResults.count) cluster records")
                return clusterResults as [Any]
            }
        }
    }
    
    // Debug function to check database contents
    func debugPrintRecords() async throws {
        _ = try await performDatabaseOperation("Debug Print Records", write: false) { db in
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
            return true  // Return a value even though we're discarding it
        }
    }
    
    // Individual field update methods for combined records
    
    // Package tracking updates
    func updatePackageStatus(forSystemAccount: String, adGroup: String, status: String) async throws {
        _ = try await performDatabaseOperation("Update Package Status", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationPackageStatus = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [status, forSystemAccount, adGroup]
            )
            return true
        }
    }
    
    func updatePackageReadinessDate(forSystemAccount: String, adGroup: String, date: Date) async throws {
        _ = try await performDatabaseOperation("Update Package Readiness Date", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationPackageReadinessDate = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [date, forSystemAccount, adGroup]
            )
            return true
        }
    }
    
    // Test tracking updates
    func updateTestStatus(forSystemAccount: String, adGroup: String, status: String) async throws {
        _ = try await performDatabaseOperation("Update Test Status", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationTestStatus = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [status, forSystemAccount, adGroup]
            )
            return true
        }
    }
    
    func updateTestReadinessDate(forSystemAccount: String, adGroup: String, date: Date) async throws {
        _ = try await performDatabaseOperation("Update Test Readiness Date", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET applicationTestReadinessDate = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [date, forSystemAccount, adGroup]
            )
            return true
        }
    }
    
    // Department and Migration updates
    func updateDepartmentSimple(forSystemAccount: String, adGroup: String, department: String) async throws {
        _ = try await performDatabaseOperation("Update Department Simple", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET departmentSimple = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [department, forSystemAccount, adGroup]
            )
            return true
        }
    }
    
    func updateMigrationCluster(forSystemAccount: String, adGroup: String, cluster: String) async throws {
        _ = try await performDatabaseOperation("Update Migration Cluster", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET migrationCluster = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [cluster, forSystemAccount, adGroup]
            )
            return true
        }
    }
    
    func updateMigrationReadiness(forSystemAccount: String, adGroup: String, readiness: String) async throws {
        _ = try await performDatabaseOperation("Update Migration Readiness", write: true) { db in
            try db.execute(
                sql: """
                    UPDATE combined_records
                    SET migrationReadiness = ?
                    WHERE systemAccount = ? AND adGroup = ?
                    """,
                arguments: [readiness, forSystemAccount, adGroup]
            )
            return true
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
        try await performDatabaseOperation("Check Database State", write: false) { db in
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
        try await performDatabaseOperation("Generate Package Records", write: true) { db in
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
        try await performDatabaseOperation("Save Test Records", write: true) { db in
            var counts = (saved: 0, skipped: 0)
            
            for record in records {
                let dbRecord = TestRecord(from: record)
                print("Processing test record for application: \(dbRecord.applicationName)")
                print("Test plan date: \(String(describing: record.testingPlanDate))")
                
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
                
                // Update ALL matching records in combined_records table
                // This ensures consistency across all instances of the same application
                try db.execute(
                    sql: """
                        UPDATE combined_records
                        SET applicationTestStatus = ?,
                            applicationTestReadinessDate = ?,
                            testingPlanDate = ?
                        WHERE applicationName = ?
                        """,
                    arguments: [
                        record.testStatus,
                        record.testDate,
                        record.testingPlanDate,
                        record.applicationName
                    ]
                )
                
                // Verify the update
                if let updatedRecord = try CombinedRecord
                    .filter(Column("applicationName") == record.applicationName)
                    .fetchOne(db) {
                    print("Updated combined record - Application: \(updatedRecord.applicationName)")
                    print("Test Status: \(updatedRecord.applicationTestStatus ?? "nil")")
                    print("Test Plan Date: \(String(describing: updatedRecord.testingPlanDate))")
                }
            }
            
            print("Finished saving test records - Saved: \(counts.saved), Skipped: \(counts.skipped)")
            return counts
        }
    }
    
    // Fetch test records with pagination
    func fetchTestRecords(limit: Int = 1000, offset: Int = 0) async throws -> [TestRecord] {
        try await performDatabaseOperation("Fetch Test Records", write: false) { db in
            try TestRecord
                .order(sql: "applicationName ASC")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // Generate test records from combined records
    func generateTestRecords() async throws -> Int {
        return try await performDatabaseOperation("Generate Test Records", write: true) { db in
            // First, clear existing test records
            try TestRecord.deleteAll(db)
            
            // Get all AD records to get valid application names
            let adApplicationNames = try ADRecord
                .select(Column("applicationName"))
                .asRequest(of: String.self)
                .fetchSet(db)
            
            print("Found \(adApplicationNames.count) valid application names from AD records")
            
            // Get all combined records
            let combinedRecords = try CombinedRecord.fetchAll(db)
            var testCount = 0
            
            print("Found \(combinedRecords.count) combined records to process")
            
            // Create test records from combined records, but only for valid application names
            for record in combinedRecords {
                // Only process if the application name exists in AD records
                if adApplicationNames.contains(record.applicationName) {
                    // Process if either testStatus or testingPlanDate is set
                    if let testStatus = record.applicationTestStatus {
                        print("Processing combined record for \(record.applicationName) with status: \(testStatus)")
                        
                        let testResult = switch testStatus {
                            case "Ready": "Not Started"
                            case "In Progress": "In Progress"
                            case "Completed": "Passed"
                            default: "Not Started"
                        }
                        
                        let testingData = TestingData(
                            applicationName: record.applicationName,
                            testStatus: testStatus,
                            testDate: record.applicationTestReadinessDate,
                            testResult: testResult,
                            testingPlanDate: record.testingPlanDate
                        )
                        
                        // Create test record
                        let testRecord = TestRecord(from: testingData)
                        
                        // Try to find existing record by applicationName
                        if let existingRecord = try TestRecord
                            .filter(Column("applicationName") == record.applicationName)
                            .fetchOne(db) {
                            // Update existing record with new data, preserving id
                            var updatedRecord = testRecord
                            updatedRecord.id = existingRecord.id
                            try updatedRecord.update(db)
                        } else {
                            // Insert new record
                            try testRecord.insert(db)
                        }
                        testCount += 1
                    } else if record.testingPlanDate != nil {
                        print("Processing combined record for \(record.applicationName) with test plan date but no status")
                        
                        let testingData = TestingData(
                            applicationName: record.applicationName,
                            testStatus: "Not Started",  // Default status for records with only test plan date
                            testDate: nil,
                            testResult: "Not Started",
                            testingPlanDate: record.testingPlanDate
                        )
                        
                        // Create test record
                        let testRecord = TestRecord(from: testingData)
                        
                        // Try to find existing record by applicationName
                        if let existingRecord = try TestRecord
                            .filter(Column("applicationName") == record.applicationName)
                            .fetchOne(db) {
                            // Update existing record with new data, preserving id
                            var updatedRecord = testRecord
                            updatedRecord.id = existingRecord.id
                            try updatedRecord.update(db)
                        } else {
                            // Insert new record
                            try testRecord.insert(db)
                        }
                        testCount += 1
                    }
                }
            }
            
            print("Generated \(testCount) test records")
            return testCount
        }
    }
    
    // Save migration records
    func saveMigrationRecords(_ records: [MigrationData]) async throws -> (saved: Int, skipped: Int) {
        try await performDatabaseOperation("Save Migration Records", write: true) { db in
            var counts = (saved: 0, skipped: 0)
            
            // Get all valid AD application names
            let adApplicationNames = try ADRecord
                .select(Column("applicationName"))
                .asRequest(of: String.self)
                .fetchSet(db)
            
            for data in records {
                // Only process if application exists in AD records
                if adApplicationNames.contains(data.applicationName) {
                    let record = MigrationRecord(from: data)
                    
                    // Try to find existing record by applicationName
                    if let existingRecord = try MigrationRecord
                        .filter(Column("applicationName") == data.applicationName)
                        .fetchOne(db) {
                        // Update existing record with new data, preserving id
                        var updatedRecord = record
                        updatedRecord.id = existingRecord.id
                        try updatedRecord.update(db)
                    } else {
                        // Insert new record only if it exists in AD
                        try record.insert(db)
                    }
                    
                    // Update ALL matching records in combined_records table
                    try db.execute(
                        sql: """
                            UPDATE combined_records
                            SET applicationNew = ?,
                                applicationSuiteNew = ?,
                                willBe = ?,
                                inScopeOutScopeDivision = ?,
                                migrationPlatform = ?,
                                migrationApplicationReadiness = ?
                            WHERE applicationName = ?
                            """,
                        arguments: [
                            data.applicationNew,
                            data.applicationSuiteNew,
                            data.willBe,
                            data.inScopeOutScopeDivision,
                            data.migrationPlatform,
                            data.migrationApplicationReadiness,
                            data.applicationName
                        ]
                    )
                    counts.saved += 1
                } else {
                    print("Skipping migration record for \(data.applicationName) - not found in AD records")
                    counts.skipped += 1
                }
            }
            
            return counts
        }
    }
    
    // Clear migration records
    func clearMigrationRecords() async throws {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        try await dbPool.write { db in
            _ = try MigrationRecord.deleteAll(db)
        }
    }
    
    // Fetch migration records
    func fetchMigrationRecords(limit: Int? = nil) async throws -> [MigrationRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            if let limit = limit {
                return try MigrationRecord.limit(limit).fetchAll(db)
            } else {
                return try MigrationRecord.fetchAll(db)
            }
        }
    }
    
    // Save cluster records to database with upsert behavior
    func saveClusterRecords(_ records: [ClusterData]) async throws -> (saved: Int, skipped: Int) {
        try await performDatabaseOperation("Save Cluster Records", write: true) { db in
            var counts = (saved: 0, skipped: 0)
            
            // Get all HR departments for validation
            let hrDepartments = try HRRecord
                .select(Column("department"))
                .filter(Column("department") != nil)
                .asRequest(of: String.self)
                .fetchSet(db)
            
            for record in records {
                // Validate department exists in HR records
                if !hrDepartments.contains(record.department) {
                    counts.skipped += 1
                    continue
                }
                
                let dbRecord = ClusterRecord(from: record)
                try dbRecord.insert(db)
                counts.saved += 1
            }
            
            return counts
        }
    }
    
    // Fetch cluster records with pagination
    func fetchClusterRecords(limit: Int = 1000, offset: Int = 0) async throws -> [ClusterRecord] {
        try await performDatabaseOperation("Fetch Cluster Records", write: false) { db in
            try ClusterRecord
                .order(sql: "department ASC")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // Clear cluster records
    func clearClusterRecords() async throws {
        try await performDatabaseOperation("Clear Cluster Records", write: true) { db in
            try db.execute(sql: "DELETE FROM cluster_records")
            return
        }
    }
    
    // Generic database operation handler with error handling
    private func performDatabaseOperation<T>(_ operation: String, write: Bool = false, action: @escaping (Database) throws -> T) async throws -> T {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        do {
            if write {
                return try await dbPool.write { db in
                    try action(db)
                }
            } else {
                return try await dbPool.read { db in
                    try action(db)
                }
            }
        } catch {
            print("Error during \(operation): \(error)")
            throw error
        }
    }
    
    public func reinitialize() async throws {
        // Close existing connection if any
        dbPool = nil
        
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
            let dbFolderURL = appSupportURL.appendingPathComponent("FLC", isDirectory: true)
            try fileManager.createDirectory(at: dbFolderURL, withIntermediateDirectories: true)
            
            let dbURL = dbFolderURL.appendingPathComponent("database.sqlite")
            print("Database path: \(dbURL.path)")
            
            // Force recreation by removing the old database
            try? fileManager.removeItem(at: dbURL)
            
            // Reset the version in UserDefaults to force recreation
            let defaults = UserDefaults.standard
            defaults.set(0, forKey: versionKey)
            
            // Create new database connection
            dbPool = try DatabasePool(path: dbURL.path)
            try createTables()
            
            // Ensure initial data is seeded
            ensureInitialData()
        } catch {
            print("Database reinitialization error: \(error)")
            throw error
        }
    }
    
    // Function to get the database file path
    func getDatabasePath() throws -> String {
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find Application Support directory"])
        }
        
        let flcDir = appSupportDir.appendingPathComponent("FLC")
        return flcDir.appendingPathComponent("database.sqlite").path
    }
    
    // Fetch all unique AD application names
    func fetchADApplicationNames() async throws -> [String] {
        try await performDatabaseOperation("Fetch AD Application Names", write: false) { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT applicationName FROM ad_records")
        }
    }
    
    // Synchronous check for AD application existence
    func hasADApplication(_ applicationName: String) -> Bool {
        guard let dbPool = dbPool else { return false }
        do {
            return try dbPool.read { db in
                try String.fetchAll(db, sql: "SELECT DISTINCT applicationName FROM ad_records")
                    .contains { $0.lowercased() == applicationName.lowercased() }
            }
        } catch {
            print("Error checking AD application: \(error)")
            return false
        }
    }
} 