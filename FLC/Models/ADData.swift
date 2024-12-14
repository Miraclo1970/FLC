import Foundation

struct ADData: Codable, Identifiable, Hashable {
    var id: String { "\(adGroup)|\(systemAccount)" }  // Composite key for uniqueness
    
    let adGroup: String
    let systemAccount: String
    let applicationName: String
    let applicationSuite: String
    let otap: String
    let critical: String
    
    init(adGroup: String, systemAccount: String, applicationName: String? = nil, applicationSuite: String? = nil, otap: String? = nil, critical: String? = nil) {
        self.adGroup = adGroup
        self.systemAccount = systemAccount
        self.applicationName = applicationName ?? "N/A"
        self.applicationSuite = applicationSuite ?? "N/A"
        self.otap = otap ?? "N/A"
        self.critical = critical ?? "N/A"
    }
    
    // Validation errors
    var validationErrors: [String] {
        var errors: [String] = []
        
        // Validate required fields
        if adGroup.isEmpty || adGroup == "N/A" {
            errors.append("AD Group is required")
        }
        if systemAccount.isEmpty || systemAccount == "N/A" {
            errors.append("System Account is required")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    // Hashable conformance for uniqueness checking
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ADData, rhs: ADData) -> Bool {
        return lhs.id == rhs.id
    }
} 