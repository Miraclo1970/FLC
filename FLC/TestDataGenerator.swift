import Foundation

class TestDataGenerator {
    static func generateADTestData() -> [ADData] {
        var testData: [ADData] = []
        
        // Test cases with various system account patterns
        let testCases: [(adGroup: String, systemAccount: String, app: String, suite: String, otap: String, critical: String)] = [
            ("FLC_Admin", "sz12345", "FileShare", "Infrastructure", "P", "YES"),
            ("FLC_User", "sz54321", "SAP", "Business Apps", "P", "NO"),
            ("FLC_Read", "sz98765", "Oracle", "Database", "T", "YES"),
            ("FLC_Write", "sz24680", "SharePoint", "Collaboration", "A", "NO"),
            ("FLC_Execute", "sz13579", "Active Directory", "Infrastructure", "P", "YES"),
            ("SAP_User", "sz11111", "SAP", "Business Apps", "P", "YES"),
            ("DB_Admin", "sz22222", "Oracle", "Database", "P", "YES"),
            ("Share_Admin", "sz33333", "FileShare", "Infrastructure", "T", "NO"),
            ("App_User", "sz44444", "Custom App", "Business Apps", "A", "NO"),
            ("Sys_Admin", "sz55555", "System Tools", "Infrastructure", "P", "YES")
        ]
        
        // Add all test cases
        for testCase in testCases {
            let adData = ADData(
                adGroup: testCase.adGroup,
                systemAccount: testCase.systemAccount,
                applicationName: testCase.app,
                applicationSuite: testCase.suite,
                otap: testCase.otap,
                critical: testCase.critical
            )
            testData.append(adData)
        }
        
        return testData
    }
    
    static func generateHRTestData() -> [HRData] {
        var testData: [HRData] = []
        
        // Test cases with various scenarios including leave dates
        let testCases: [(systemAccount: String, dept: String, role: String, div: String, leaveDate: Date?, empNum: String)] = [
            ("sz12345", "IT", "System Administrator", "Operations", nil, "EMP001"),
            ("sz54321", "Finance", "Business Analyst", "Business", Date().addingTimeInterval(60*60*24*30), "EMP002"), // Leaving in 30 days
            ("sz98765", "IT", "Database Admin", "Operations", nil, "EMP003"),
            ("sz24680", "HR", "HR Manager", "Support", nil, "EMP004"),
            ("sz13579", "IT", "Network Engineer", "Infrastructure", Date().addingTimeInterval(-60*60*24*30), "EMP005"), // Left 30 days ago
            ("sz11111", "Finance", "SAP Specialist", "Business", nil, "EMP006"),
            ("sz22222", "IT", "Database Manager", "Operations", nil, "EMP007"),
            ("sz33333", "Operations", "System Engineer", "Infrastructure", nil, "EMP008"),
            ("sz44444", "Development", "Software Engineer", "IT", Date().addingTimeInterval(60*60*24*60), "EMP009"), // Leaving in 60 days
            ("sz55555", "IT", "System Architect", "Infrastructure", nil, "EMP010")
        ]
        
        // Add all test cases
        for testCase in testCases {
            let hrData = HRData(
                systemAccount: testCase.systemAccount,
                department: testCase.dept,
                jobRole: testCase.role,
                division: testCase.div,
                leaveDate: testCase.leaveDate,
                employeeNumber: testCase.empNum
            )
            testData.append(hrData)
        }
        
        return testData
    }
    
    static func generatePackageStatusData() -> [PackageStatusData] {
        var testData: [PackageStatusData] = []
        
        // Test cases with various package status scenarios
        let testCases: [(applicationName: String, status: String, readinessDate: Date?)] = [
            ("FileShare", "Ready for Packaging", Date().addingTimeInterval(60*60*24*7)),  // Ready in 1 week
            ("SAP", "In Progress", Date().addingTimeInterval(60*60*24*14)),  // Ready in 2 weeks
            ("Oracle", "Not Started", Date().addingTimeInterval(60*60*24*30)),  // Ready in 1 month
            ("SharePoint", "Blocked", nil),  // No date set
            ("Active Directory", "Ready for Testing", Date()),  // Ready now
            ("Custom App", "Package Failed", nil),  // Failed without date
            ("System Tools", "Ready for Production", Date().addingTimeInterval(-60*60*24*7)),  // Ready 1 week ago
            ("Email Client", "Awaiting Approval", Date().addingTimeInterval(60*60*24*21)),  // Ready in 3 weeks
            ("Database Tool", "In Review", Date().addingTimeInterval(60*60*24*10)),  // Ready in 10 days
            ("Security Scanner", "Pending Dependencies", nil)  // No date set
        ]
        
        // Add all test cases
        for testCase in testCases {
            let packageData = PackageStatusData(
                id: nil,
                systemAccount: "",  // Not used for package status
                applicationName: testCase.applicationName,
                packageStatus: testCase.status,
                packageReadinessDate: testCase.readinessDate,
                importDate: Date(),
                importSet: "TEST_\(UUID().uuidString)"
            )
            testData.append(packageData)
        }
        
        return testData
    }
    
    static func generateTestingData() -> [TestingData] {
        var testData: [TestingData] = []
        
        // Test cases with various test scenarios
        let testCases: [(applicationName: String, status: String, result: String, comments: String?)] = [
            ("FileShare", "Completed", "Pass", "All test cases passed"),
            ("SAP", "In Progress", "Pending", "Testing core functionality"),
            ("Oracle", "Not Started", "Not Tested", nil),
            ("SharePoint", "Failed", "Fail", "Critical issues found in security module"),
            ("Active Directory", "Completed", "Pass with Notes", "Minor issues documented"),
            ("Custom App", "Blocked", "Blocked", "Waiting for package deployment"),
            ("System Tools", "Completed", "Pass", "Performance tests successful"),
            ("Email Client", "In Progress", "Pending", "50% test cases completed"),
            ("Database Tool", "Completed", "Conditional Pass", "Needs security review"),
            ("Security Scanner", "Not Started", "Not Tested", "Scheduled for next sprint")
        ]
        
        // Add all test cases
        for testCase in testCases {
            let testingData = TestingData(
                applicationName: testCase.applicationName,
                testStatus: testCase.status,
                testDate: Date(),  // Current date for simplicity
                testResult: testCase.result,
                testComments: testCase.comments
            )
            testData.append(testingData)
        }
        
        return testData
    }
} 