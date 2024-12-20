import Foundation
import GRDB

struct PackageStatusData: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: Int64?
    let applicationName: String
    let packageStatus: String
    let packageReadinessDate: Date?
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "package_status_records"
    
    var uniqueIdentifier: String {
        "\(applicationName)_\(importSet)"
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if applicationName.isEmpty || applicationName == "N/A" || applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Application Name is required")
        }
        
        // Package Status is now optional, so we don't validate it
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    // Normalize application name for comparison
    var normalizedApplicationName: String {
        return applicationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // Hashable conformance for uniqueness checking
    static func == (lhs: PackageStatusData, rhs: PackageStatusData) -> Bool {
        return lhs.normalizedApplicationName == rhs.normalizedApplicationName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedApplicationName)
    }
}
