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
