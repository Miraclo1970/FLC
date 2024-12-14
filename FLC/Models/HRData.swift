import Foundation

struct HRData: Codable, Identifiable, Hashable {
    var id: String { systemAccount }  // Using systemAccount as unique identifier
    
    let systemAccount: String
    let department: String?
    let jobRole: String?
    let division: String?
    let leaveDate: Date?
    let employeeNumber: String?
    
    // Validation errors
    var validationErrors: [String] {
        var errors: [String] = []
        
        // Only validate that system account is not empty
        if systemAccount.isEmpty || systemAccount == "N/A" {
            errors.append("System Account is required")
        }
        
        return errors
    }
    
    var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: HRData, rhs: HRData) -> Bool {
        return lhs.id == rhs.id
    }
}

// Extension to handle date formatting
extension DateFormatter {
    static let hrDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.isLenient = true  // Make parsing more lenient
        return formatter
    }()
    
    static let hrDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"  // Alternative format for parsing
        formatter.isLenient = true
        return formatter
    }()
    
    static func parseHRDate(_ dateString: String) -> Date? {
        // Try the standard format first
        if let date = hrDateFormatter.date(from: dateString) {
            return date
        }
        // Try the alternative format
        return hrDateParser.date(from: dateString)
    }
} 