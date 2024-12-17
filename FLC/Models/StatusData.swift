import Foundation
import GRDB

struct PackageStatusData: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: Int64?
    let systemAccount: String
    let applicationName: String
    let packageStatus: String
    let packageReadinessDate: Date?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "package_status_records"
}

struct MigrationStatusData: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: Int64?
    let adGroup: String
    let applicationName: String
    let applicationNameNew: String?
    let suite: String?
    let suiteNew: String?
    let scopeDivision: String?
    let departmentSimple: String?
    let migrationCluster: String?
    let migrationReadiness: String?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "migration_status_records"
}
