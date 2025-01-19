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

enum DataSource {
    case activeDirectory
    case humanResources
}

class DatabaseManager: ObservableObject {
    public static let shared: DatabaseManager = DatabaseManager()
    @Published private var dbPool: DatabasePool?
    @Published private(set) var currentEnvironment: Environment
    private let currentVersion = 4  // Increment this to force schema update
    private let versionKey = "database_version"
    
    private init() {
        // Load the last used environment or default to Development
        if let savedEnv = UserDefaults.standard.string(forKey: "last_environment"),
           let env = Environment(rawValue: savedEnv) {
            self.currentEnvironment = env
        } else {
            self.currentEnvironment = .development
        }
        
        // Migrate old development directory structure if needed
        migrateOldDevelopmentStructure()
        
        // Initialize database for the current environment
        initializeDatabase()
    }
    
    private func migrateOldDevelopmentStructure() {
        let fileManager = FileManager.default
        guard let baseDir = currentEnvironment.baseDirectory else { return }
        
        // Check if we need to migrate development environment
        if currentEnvironment == .development {
            let oldDbPath = baseDir.appendingPathComponent("flc.db")
            let oldShmPath = baseDir.appendingPathComponent("flc.db-shm")
            let oldWalPath = baseDir.appendingPathComponent("flc.db-wal")
            
            if fileManager.fileExists(atPath: oldDbPath.path) {
                do {
                    // Create new directory structure
                    try currentEnvironment.createDirectories()
                    
                    // Move database files to new location
                    if let newDbPath = currentEnvironment.databasePath {
                        try? fileManager.removeItem(at: newDbPath)
                        try fileManager.moveItem(at: oldDbPath, to: newDbPath)
                        
                        // Move associated SQLite files if they exist
                        if fileManager.fileExists(atPath: oldShmPath.path) {
                            let newShmPath = newDbPath.deletingLastPathComponent().appendingPathComponent("flc.db-shm")
                            try? fileManager.removeItem(at: newShmPath)
                            try fileManager.moveItem(at: oldShmPath, to: newShmPath)
                        }
                        
                        if fileManager.fileExists(atPath: oldWalPath.path) {
                            let newWalPath = newDbPath.deletingLastPathComponent().appendingPathComponent("flc.db-wal")
                            try? fileManager.removeItem(at: newWalPath)
                            try fileManager.moveItem(at: oldWalPath, to: newWalPath)
                        }
                    }
                } catch {
                    print("Migration error: \(error)")
                }
            }
        }
    }
    
    private func initializeDatabase() {
        do {
            // Ensure directories exist for current environment
            try currentEnvironment.createDirectories()
            
            // Get database path for current environment
            guard let dbURL = currentEnvironment.databasePath else {
                print("Error: Could not get database path for environment \(currentEnvironment)")
                return
            }
            
            print("Database path: \(dbURL.path)")
            
            // Check if we need to delete the existing database due to version mismatch
            let defaults = UserDefaults.standard
            let versionKey = "\(currentEnvironment.rawValue)_\(self.versionKey)"
            let savedVersion = defaults.integer(forKey: versionKey)
            
            if savedVersion < currentVersion {
                try? FileManager.default.removeItem(at: dbURL)
                defaults.set(currentVersion, forKey: versionKey)
            }
            
            // Create new database connection
            dbPool = try DatabasePool(path: dbURL.path)
            try createTables()
            
            // Only seed initial data for new databases
            if savedVersion < currentVersion {
                ensureInitialData()
            }
            
            // Save the current environment as the last used
            defaults.set(currentEnvironment.rawValue, forKey: "last_environment")
        } catch {
            print("Database initialization error: \(error)")
        }
    }
    
    // Switch to a different environment
    @MainActor
    func switchEnvironment(to newEnvironment: Environment) async throws {
        guard newEnvironment != currentEnvironment else { return }
        
        // Close existing connection
        dbPool = nil
        
        // Update current environment
        currentEnvironment = newEnvironment
        
        // Initialize database for new environment
        initializeDatabase()
        
        // Verify database connection
        guard dbPool != nil else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize database for environment \(newEnvironment)"])
        }
        
        // Notify observers of the change
        objectWillChange.send()
    }
    
    // Get the current environment's database path
    func getDatabasePath() throws -> String {
        guard let path = currentEnvironment.databasePath?.path else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get database path for environment \(currentEnvironment)"])
        }
        return path
    }
    
    // Get the current environment's derived data directory
    func getDerivedDataDirectory() throws -> URL {
        guard let directory = currentEnvironment.derivedDataDirectory else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get derived data directory for environment \(currentEnvironment)"])
        }
        return directory
    }
    
    // Add fetch method for combined records
    func fetchAllRecords() async throws -> [CombinedRecord] {
        guard let dbPool = dbPool else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No database connection"])
        }
        
        return try await dbPool.read { db in
            try CombinedRecord.fetchAll(db)
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
                t.column("migrationClusterReadiness", .text)
                // Metadata
                t.column("importDate", .datetime).notNull()
                t.column("importSet", .text).notNull()
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
            
            print("\nSaving HR Records:")
            print("Total records to save: \(records.count)")
            
            for record in records {
                print("\nProcessing HR Record:")
                print("- System Account: '\(record.systemAccount)'")
                print("- Department: '\(record.department ?? "nil")'")
                print("- Department Simple: '\(record.departmentSimple ?? "nil")'")
                
                let dbRecord = HRRecord(from: record)
                
                // Try to find existing record by systemAccount
                if let existingRecord = try HRRecord.filter(Column("systemAccount") == record.systemAccount).fetchOne(db) {
                    // Update existing record with new data, preserving systemAccount and id
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                    counts.saved += 1
                    print("- Updated existing record")
                } else {
                    // Insert new record
                    try dbRecord.insert(db)
                    counts.saved += 1
                    print("- Inserted new record")
                }
            }
            
            print("\nHR Records Save Summary:")
            print("- Total saved: \(counts.saved)")
            print("- Total skipped: \(counts.skipped)")
            
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
            
            // Get all HR records for lookup
            let hrRecords = try HRRecord.fetchAll(db)
            print("Found \(hrRecords.count) HR records for matching")
            
            // Print out some HR departments for debugging
            print("\nSample HR departments:")
            for record in hrRecords.prefix(5) {
                print("HR Department: '\(record.department ?? "nil")'")
            }
            
            // Create dictionaries for faster lookups
            let hrLookup = Dictionary(uniqueKeysWithValues: hrRecords.map { ($0.systemAccount, $0) })
            let packageRecords = try PackageRecord.fetchAll(db)
            let packageLookup = Dictionary(uniqueKeysWithValues: packageRecords.map { ($0.applicationName, $0) })
            let testRecords = try TestRecord.fetchAll(db)
            let testLookup = Dictionary(uniqueKeysWithValues: testRecords.map { ($0.applicationName, $0) })
            let migrationRecords = try MigrationRecord.fetchAll(db)
            let migrationLookup = Dictionary(uniqueKeysWithValues: migrationRecords.map { ($0.applicationName, $0) })
            
            var combinedCount = 0
            
            // First pass: Create combined records from AD and HR data
            for adRecord in adRecords {
                // Get HR record if it exists
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
                    clusterRecord: nil,  // Will be updated in second pass
                    importDate: Date(),
                    importSet: "Combined_\(DateFormatter.hrDateFormatter.string(from: Date()))"
                )
                
                try combinedRecord.insert(db)
                combinedCount += 1
                
                if combinedCount % 100 == 0 {
                    print("Created \(combinedCount) combined records...")
                }
            }
            
            // Second pass: Update all records with cluster data based on department
            let clusterRecords = try ClusterRecord.fetchAll(db)
            print("\nFound \(clusterRecords.count) cluster records for matching")
            
            // Print all unique readiness values in cluster records
            let uniqueReadinessValues = Set(clusterRecords.compactMap { $0.migrationClusterReadiness })
            print("\nUnique readiness values in cluster records:")
            for value in uniqueReadinessValues.sorted() {
                print("- '\(value)'")
            }
            
            for clusterRecord in clusterRecords {
                // Count how many records match this department
                let matchCount = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM combined_records 
                    WHERE department = ?
                    """, arguments: [clusterRecord.department]) ?? 0
                
                print("\nProcessing cluster record:")
                print("- Department: '\(clusterRecord.department)'")
                print("- Matches found: \(matchCount)")
                print("- Cluster: '\(clusterRecord.migrationCluster ?? "nil")'")
                print("- Readiness: '\(clusterRecord.migrationClusterReadiness ?? "nil")'")
                
                // Skip if no matches found
                if matchCount == 0 {
                    print("- WARNING: No matching combined records found for department")
                    continue
                }
                
                // Update all combined records that have a matching department
                try db.execute(
                    sql: """
                        UPDATE combined_records
                        SET departmentSimple = ?,
                            domain = ?,
                            migrationCluster = ?,
                            migrationClusterReadiness = ?
                        WHERE department = ?
                        """,
                    arguments: [
                        clusterRecord.departmentSimple,
                        clusterRecord.domain,
                        clusterRecord.migrationCluster,
                        clusterRecord.migrationClusterReadiness,
                        clusterRecord.department
                    ]
                )
                
                // Verify the update by checking the actual values in the database
                let updatedValues = try Row.fetchAll(db, sql: """
                    SELECT migrationClusterReadiness 
                    FROM combined_records 
                    WHERE department = ?
                    """,
                    arguments: [clusterRecord.department]
                )
                
                print("Updated values in combined_records:")
                for row in updatedValues {
                    if let readiness = row[0] as? String {
                        print("- Readiness after update: '\(readiness)'")
                    }
                }
            }
            
            // Final verification of all readiness values
            print("\nFinal verification of readiness values in combined_records:")
            let allReadinessValues = try String.fetchAll(db, sql: """
                SELECT DISTINCT migrationClusterReadiness 
                FROM combined_records 
                WHERE migrationClusterReadiness IS NOT NULL 
                AND migrationClusterReadiness != ''
                """)
            
            print("All distinct readiness values in combined_records:")
            for value in allReadinessValues.sorted() {
                print("- '\(value)'")
            }
            
            print("Generated \(combinedCount) combined records and updated with cluster data")
            return combinedCount
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
    
    // Save package status records
    func savePackageStatusRecords(_ records: [PackageStatusData]) async throws -> (saved: Int, skipped: Int) {
        try await performDatabaseOperation("Save Package Status Records", write: true) { db in
            var counts = (saved: 0, skipped: 0)
            
            // Get all valid AD application names
            let adApplicationNames = try ADRecord
                .select(Column("applicationName"))
                .asRequest(of: String.self)
                .fetchSet(db)
            
            for data in records {
                // Only process if application exists in AD records
                if adApplicationNames.contains(data.applicationName) {
                    let record = PackageRecord(from: data)
                    
                    // Try to find existing record by applicationName
                    if let existingRecord = try PackageRecord
                        .filter(Column("applicationName") == data.applicationName)
                        .fetchOne(db) {
                        // Always update the package record
                        var updatedRecord = record
                        updatedRecord.id = existingRecord.id
                        try updatedRecord.update(db)
                        
                        // Only update combined records table if we have non-empty values
                        var updateFields: [(String, (any DatabaseValueConvertible)?)] = []
                        
                        if !data.packageStatus.isEmpty && data.packageStatus != "N/A" {
                            updateFields.append(("applicationPackageStatus", data.packageStatus))
                        }
                        if data.packageReadinessDate != nil {
                            updateFields.append(("applicationPackageReadinessDate", data.packageReadinessDate))
                        }
                        
                        if !updateFields.isEmpty {
                            // Build dynamic SQL update statement
                            let setClause = updateFields.map { "\($0.0) = ?" }.joined(separator: ", ")
                            let sql = """
                                UPDATE combined_records
                                SET \(setClause)
                                WHERE applicationName = ?
                                """
                            
                            // Create arguments array and convert to StatementArguments
                            let arguments: [(any DatabaseValueConvertible)?] = updateFields.map { $0.1 } + [data.applicationName]
                            try db.execute(sql: sql, arguments: StatementArguments(arguments))
                        }
                        counts.saved += 1
                    } else {
                        // Always insert new record
                        try record.insert(db)
                        counts.saved += 1
                    }
                } else {
                    counts.skipped += 1
                }
            }
            return counts
        }
    }
    
    // Save test records to database with upsert behavior
    func saveTestRecords(_ records: [TestingData]) async throws -> (saved: Int, skipped: Int) {
        try await performDatabaseOperation("Save Test Records", write: true) { db in
            var counts = (saved: 0, skipped: 0)
            
            // Get all valid AD application names
            let adApplicationNames = try ADRecord
                .select(Column("applicationName"))
                .asRequest(of: String.self)
                .fetchSet(db)
            
            for record in records {
                // Only process if application exists in AD records
                if adApplicationNames.contains(record.applicationName) {
                    let dbRecord = TestRecord(from: record)
                    print("Processing test record for application: \(dbRecord.applicationName)")
                    
                    // Try to find existing record by applicationName only
                    if let existingRecord = try TestRecord
                        .filter(Column("applicationName") == record.applicationName)
                        .fetchOne(db) {
                        print("Found existing record for \(dbRecord.applicationName), updating...")
                        
                        // Always update the test record
                        var updatedRecord = dbRecord
                        updatedRecord.id = existingRecord.id
                        try updatedRecord.update(db)
                        
                        // Only update combined records table if we have non-empty values
                        var updateFields: [(String, (any DatabaseValueConvertible)?)] = []
                        
                        if !record.testStatus.isEmpty && record.testStatus != "N/A" {
                            updateFields.append(("applicationTestStatus", record.testStatus))
                        }
                        if !record.testResult.isEmpty && record.testResult != "N/A" {
                            updateFields.append(("testResult", record.testResult))
                        }
                        if record.testDate != nil {
                            updateFields.append(("applicationTestReadinessDate", record.testDate))
                        }
                        if record.testingPlanDate != nil {
                            updateFields.append(("testingPlanDate", record.testingPlanDate))
                        }
                        
                        if !updateFields.isEmpty {
                            // Build dynamic SQL update statement
                            let setClause = updateFields.map { "\($0.0) = ?" }.joined(separator: ", ")
                            let sql = """
                                UPDATE combined_records
                                SET \(setClause)
                                WHERE applicationName = ?
                                """
                            
                            // Create arguments array and convert to StatementArguments
                            let arguments: [(any DatabaseValueConvertible)?] = updateFields.map { $0.1 } + [record.applicationName]
                            try db.execute(sql: sql, arguments: StatementArguments(arguments))
                        }
                        counts.saved += 1
                    } else {
                        print("No existing record for \(dbRecord.applicationName), inserting new record...")
                        // Always insert new record
                        try dbRecord.insert(db)
                        counts.saved += 1
                    }
                } else {
                    counts.skipped += 1
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
            
            print("\nSaving Cluster Records:")
            print("Total records to save: \(records.count)")
            
            // Get all HR departments for validation
            let hrDepartments = try HRRecord
                .select(Column("department"))
                .filter(Column("department") != nil)
                .asRequest(of: String.self)
                .fetchSet(db)
            
            print("\nFound \(hrDepartments.count) HR departments for validation")
            print("Sample HR departments:")
            for dept in hrDepartments.prefix(5) {
                print("- '\(dept)'")
            }
            
            for record in records {
                print("\nProcessing Cluster Record:")
                print("- Department: '\(record.department)'")
                print("- Migration Cluster: '\(record.migrationCluster ?? "nil")'")
                print("- Migration Cluster Readiness: '\(record.migrationClusterReadiness ?? "nil")'")
                
                // Validate department exists in HR records with exact match
                if !hrDepartments.contains(record.department) {
                    print("- WARNING: Department not found in HR records")
                    print("- Available HR departments that start with same prefix:")
                    for dept in hrDepartments.filter({ $0.hasPrefix(String(record.department.prefix(8))) }) {
                        print("  - '\(dept)'")
                    }
                    counts.skipped += 1
                    continue
                }
                
                print("- Found matching HR department")
                
                let dbRecord = ClusterRecord(from: record)
                
                // Try to find existing record
                if let existingRecord = try ClusterRecord.filter(Column("department") == record.department).fetchOne(db) {
                    // Update existing record with new data, preserving id
                    var updatedRecord = dbRecord
                    updatedRecord.id = existingRecord.id
                    try updatedRecord.update(db)
                    print("- Updated existing record")
                } else {
                    // Insert new record
                    try dbRecord.insert(db)
                    print("- Inserted new record")
                }
                
                counts.saved += 1
            }
            
            print("\nCluster Records Summary:")
            print("- Total processed: \(records.count)")
            print("- Saved: \(counts.saved)")
            print("- Skipped: \(counts.skipped)")
            
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
        _ = try await performDatabaseOperation("Clear Cluster Records", write: true) { db in
            try db.execute(sql: "DELETE FROM cluster_records")
            try db.execute(sql: "DELETE FROM sqlite_sequence WHERE name='cluster_records'")
            return true
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
            
            // Get the app's container directory
            guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "nl.jillten.FLC") else {
                print("Error: Could not get container URL")
                return
            }
            
            let dbFolderURL = containerURL.appendingPathComponent("Library/Application Support/FLC", isDirectory: true)
            try fileManager.createDirectory(at: dbFolderURL, withIntermediateDirectories: true)
            
            let dbURL = dbFolderURL.appendingPathComponent("flc.db")
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
    
    func getLastImportDate(for source: DataSource) async throws -> Date? {
        let query: String
        switch source {
        case .activeDirectory:
            query = "SELECT MAX(importDate) as lastImport FROM ad_records"
        case .humanResources:
            query = "SELECT MAX(importDate) as lastImport FROM hr_records"
        }
        
        return try await performDatabaseOperation("Get Last Import Date", write: false) { db in
            let row = try Row.fetchOne(db, sql: query)
            return row?["lastImport"]
        }
    }
    
    func getLatestImportDate(from table: String) async throws -> Date? {
        return try await performDatabaseOperation("Get Latest Import Date", write: false) { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT importSet, importDate 
                FROM \(table) 
                ORDER BY importDate DESC 
                LIMIT 1
                """)
            return row?["importDate"]
        }
    }
    
    // Check if a migration application name already exists
    func isDuplicateMigrationApplication(_ applicationName: String) -> Bool {
        guard let dbPool = dbPool else { return false }
        
        do {
            return try dbPool.read { db in
                try MigrationRecord
                    .filter(Column("applicationName").lowercased == applicationName.lowercased())
                    .fetchCount(db) > 0
            }
        } catch {
            print("Error checking for duplicate migration application: \(error)")
            return false
        }
    }
} 