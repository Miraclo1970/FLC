import Foundation
import GRDB

struct CombinedRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    
    // AD Data fields
    let adGroup: String
    let applicationName: String
    let applicationSuite: String
    let otap: String
    let critical: String
    
    // HR Data fields
    let systemAccount: String  // Common field between AD and HR
    let department: String?
    let jobRole: String?
    let division: String?
    let leaveDate: Date?
    let employeeNumber: String?
    
    // Metadata
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "combined_records"
    
    init(adRecord: ADRecord, hrRecord: HRRecord?) {
        self.id = nil
        
        // AD fields
        self.adGroup = adRecord.adGroup
        self.systemAccount = adRecord.systemAccount
        self.applicationName = adRecord.applicationName
        self.applicationSuite = adRecord.applicationSuite
        self.otap = adRecord.otap
        self.critical = adRecord.critical
        
        // HR fields (use nil if no HR record found)
        self.department = hrRecord?.department
        self.jobRole = hrRecord?.jobRole
        self.division = hrRecord?.division
        self.leaveDate = hrRecord?.leaveDate
        self.employeeNumber = hrRecord?.employeeNumber
        
        // Use the most recent import date and create a combined import set
        self.importDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "Combined_Import_\(dateFormatter.string(from: Date()))"
    }
} 