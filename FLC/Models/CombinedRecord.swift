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
    
    // Package tracking fields
    var applicationPackageStatus: String?
    var applicationPackageReadinessDate: Date?
    
    // Test tracking fields
    var applicationTestStatus: String?
    var applicationTestReadinessDate: Date?
    
    // Department and Migration fields
    var departmentSimple: String?
    var migrationCluster: String?
    var migrationReadiness: String?
    
    // Metadata
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "combined_records"
    
    init(id: Int64?,
         adGroup: String,
         systemAccount: String,
         applicationName: String,
         applicationSuite: String,
         otap: String,
         critical: String,
         department: String?,
         jobRole: String?,
         division: String?,
         leaveDate: Date?,
         applicationPackageStatus: String?,
         applicationPackageReadinessDate: Date?,
         applicationTestStatus: String?,
         applicationTestReadinessDate: Date?,
         departmentSimple: String?,
         migrationCluster: String?,
         migrationReadiness: String?,
         importDate: Date,
         importSet: String) {
        self.id = id
        self.adGroup = adGroup
        self.systemAccount = systemAccount
        self.applicationName = applicationName
        self.applicationSuite = applicationSuite
        self.otap = otap
        self.critical = critical
        self.department = department
        self.jobRole = jobRole
        self.division = division
        self.leaveDate = leaveDate
        self.applicationPackageStatus = applicationPackageStatus
        self.applicationPackageReadinessDate = applicationPackageReadinessDate
        self.applicationTestStatus = applicationTestStatus
        self.applicationTestReadinessDate = applicationTestReadinessDate
        self.departmentSimple = departmentSimple
        self.migrationCluster = migrationCluster
        self.migrationReadiness = migrationReadiness
        self.importDate = importDate
        self.importSet = importSet
    }
    
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
        
        // Package tracking fields (initialized as nil)
        self.applicationPackageStatus = nil
        self.applicationPackageReadinessDate = nil
        
        // Test tracking fields (initialized as nil)
        self.applicationTestStatus = nil
        self.applicationTestReadinessDate = nil
        
        // Department and Migration fields (initialized as nil)
        self.departmentSimple = nil
        self.migrationCluster = nil
        self.migrationReadiness = nil
        
        // Metadata
        self.importDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        self.importSet = "Combined_\(dateFormatter.string(from: Date()))"
    }
} 