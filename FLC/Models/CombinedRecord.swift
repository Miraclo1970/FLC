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
    var testResult: String?
    var testingPlanDate: Date?
    
    // Migration fields
    var applicationNew: String?
    var applicationSuiteNew: String?
    var willBe: String?
    var inScopeOutScopeDivision: String?
    var migrationPlatform: String?
    var migrationApplicationReadiness: String?
    
    // Department and Migration fields
    var departmentSimple: String?
    var domain: String?
    var migrationCluster: String?
    var migrationClusterReadiness: String?
    
    // Metadata
    let importDate: Date
    let importSet: String
    
    static let databaseTableName = "combined_records"
    
    // Define CodingKeys for proper encoding/decoding
    enum CodingKeys: String, CodingKey {
        case id
        // AD fields
        case adGroup
        case applicationName
        case applicationSuite
        case otap
        case critical
        // HR fields
        case systemAccount
        case department
        case jobRole
        case division
        case leaveDate
        // Package tracking fields
        case applicationPackageStatus
        case applicationPackageReadinessDate
        // Test tracking fields
        case applicationTestStatus
        case applicationTestReadinessDate
        case testResult
        case testingPlanDate
        // Migration fields
        case applicationNew
        case applicationSuiteNew
        case willBe
        case inScopeOutScopeDivision
        case migrationPlatform
        case migrationApplicationReadiness
        // Department and Migration fields
        case departmentSimple
        case domain
        case migrationCluster
        case migrationClusterReadiness
        // Metadata
        case importDate
        case importSet
    }
    
    // Explicitly define the columns for GRDB
    enum Columns {
        static let id = Column("id")
        // AD fields
        static let adGroup = Column("adGroup")
        static let applicationName = Column("applicationName")
        static let applicationSuite = Column("applicationSuite")
        static let otap = Column("otap")
        static let critical = Column("critical")
        // HR fields
        static let systemAccount = Column("systemAccount")
        static let department = Column("department")
        static let jobRole = Column("jobRole")
        static let division = Column("division")
        static let leaveDate = Column("leaveDate")
        // Package tracking fields
        static let applicationPackageStatus = Column("applicationPackageStatus")
        static let applicationPackageReadinessDate = Column("applicationPackageReadinessDate")
        // Test tracking fields
        static let applicationTestStatus = Column("applicationTestStatus")
        static let applicationTestReadinessDate = Column("applicationTestReadinessDate")
        static let testResult = Column("testResult")
        static let testingPlanDate = Column("testingPlanDate")
        // Migration fields
        static let applicationNew = Column("applicationNew")
        static let applicationSuiteNew = Column("applicationSuiteNew")
        static let willBe = Column("willBe")
        static let inScopeOutScopeDivision = Column("inScopeOutScopeDivision")
        static let migrationPlatform = Column("migrationPlatform")
        static let migrationApplicationReadiness = Column("migrationApplicationReadiness")
        // Department and Migration fields
        static let departmentSimple = Column("departmentSimple")
        static let domain = Column("domain")
        static let migrationCluster = Column("migrationCluster")
        static let migrationClusterReadiness = Column("migrationClusterReadiness")
        // Metadata
        static let importDate = Column("importDate")
        static let importSet = Column("importSet")
    }
    
    // Define persistence behavior
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        // AD fields
        container[Columns.adGroup] = adGroup
        container[Columns.applicationName] = applicationName
        container[Columns.applicationSuite] = applicationSuite
        container[Columns.otap] = otap
        container[Columns.critical] = critical
        // HR fields
        container[Columns.systemAccount] = systemAccount
        container[Columns.department] = department
        container[Columns.jobRole] = jobRole
        container[Columns.division] = division
        container[Columns.leaveDate] = leaveDate
        // Package tracking fields
        container[Columns.applicationPackageStatus] = applicationPackageStatus
        container[Columns.applicationPackageReadinessDate] = applicationPackageReadinessDate
        // Test tracking fields
        container[Columns.applicationTestStatus] = applicationTestStatus
        container[Columns.applicationTestReadinessDate] = applicationTestReadinessDate
        container[Columns.testResult] = testResult
        container[Columns.testingPlanDate] = testingPlanDate
        // Migration fields
        container[Columns.applicationNew] = applicationNew
        container[Columns.applicationSuiteNew] = applicationSuiteNew
        container[Columns.willBe] = willBe
        container[Columns.inScopeOutScopeDivision] = inScopeOutScopeDivision
        container[Columns.migrationPlatform] = migrationPlatform
        container[Columns.migrationApplicationReadiness] = migrationApplicationReadiness
        // Department and Migration fields
        container[Columns.departmentSimple] = departmentSimple
        container[Columns.domain] = domain
        container[Columns.migrationCluster] = migrationCluster
        container[Columns.migrationClusterReadiness] = migrationClusterReadiness
        // Metadata
        container[Columns.importDate] = importDate
        container[Columns.importSet] = importSet
    }
    
    // Define custom column encoding strategy
    static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .custom { key in
        switch key {
        case CodingKeys.adGroup: return "adGroup"
        case CodingKeys.systemAccount: return "systemAccount"
        case CodingKeys.applicationName: return "applicationName"
        case CodingKeys.applicationSuite: return "applicationSuite"
        case CodingKeys.jobRole: return "jobRole"
        case CodingKeys.leaveDate: return "leaveDate"
        case CodingKeys.applicationPackageStatus: return "applicationPackageStatus"
        case CodingKeys.applicationPackageReadinessDate: return "applicationPackageReadinessDate"
        case CodingKeys.applicationTestStatus: return "applicationTestStatus"
        case CodingKeys.applicationTestReadinessDate: return "applicationTestReadinessDate"
        case CodingKeys.applicationNew: return "applicationNew"
        case CodingKeys.applicationSuiteNew: return "applicationSuiteNew"
        case CodingKeys.inScopeOutScopeDivision: return "inScopeOutScopeDivision"
        case CodingKeys.migrationPlatform: return "migrationPlatform"
        case CodingKeys.migrationApplicationReadiness: return "migrationApplicationReadiness"
        case CodingKeys.departmentSimple: return "departmentSimple"
        case CodingKeys.domain: return "domain"
        case CodingKeys.migrationCluster: return "migrationCluster"
        case CodingKeys.migrationClusterReadiness: return "migrationClusterReadiness"
        case CodingKeys.importDate: return "importDate"
        case CodingKeys.importSet: return "importSet"
        default: return key.stringValue
        }
    }
    
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
         applicationNew: String?,
         applicationSuiteNew: String?,
         willBe: String?,
         inScopeOutScopeDivision: String?,
         migrationPlatform: String?,
         migrationApplicationReadiness: String?,
         departmentSimple: String?,
         domain: String?,
         migrationCluster: String?,
         migrationClusterReadiness: String?,
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
        self.applicationNew = applicationNew
        self.applicationSuiteNew = applicationSuiteNew
        self.willBe = willBe
        self.inScopeOutScopeDivision = inScopeOutScopeDivision
        self.migrationPlatform = migrationPlatform
        self.migrationApplicationReadiness = migrationApplicationReadiness
        self.departmentSimple = departmentSimple
        self.domain = domain
        self.migrationCluster = migrationCluster
        self.migrationClusterReadiness = migrationClusterReadiness
        self.importDate = importDate
        self.importSet = importSet
    }
    
    init(adRecord: ADRecord, hrRecord: HRRecord?, packageRecord: PackageRecord?, testRecord: TestRecord?, migrationRecord: MigrationRecord?, clusterRecord: ClusterRecord?, importDate: Date, importSet: String) {
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
        
        // Package tracking fields
        self.applicationPackageStatus = packageRecord?.packageStatus
        self.applicationPackageReadinessDate = packageRecord?.packageReadinessDate
        
        // Test tracking fields
        self.applicationTestStatus = testRecord?.testStatus
        self.applicationTestReadinessDate = testRecord?.testDate
        self.testResult = testRecord?.testResult
        self.testingPlanDate = testRecord?.testingPlanDate
        
        // Migration fields
        self.applicationNew = migrationRecord?.applicationNew
        self.applicationSuiteNew = migrationRecord?.applicationSuiteNew
        self.willBe = migrationRecord?.willBe
        self.inScopeOutScopeDivision = migrationRecord?.inScopeOutScopeDivision
        self.migrationPlatform = migrationRecord?.migrationPlatform
        self.migrationApplicationReadiness = migrationRecord?.migrationApplicationReadiness
        
        // Department and Migration fields
        // Use Cluster's departmentSimple if available, otherwise fall back to HR's
        self.departmentSimple = clusterRecord?.departmentSimple ?? hrRecord?.departmentSimple
        self.domain = clusterRecord?.domain
        self.migrationCluster = clusterRecord?.migrationCluster
        self.migrationClusterReadiness = clusterRecord?.migrationClusterReadiness
        
        // Metadata
        self.importDate = importDate
        self.importSet = importSet
    }
} 