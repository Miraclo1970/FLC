import Foundation

class TestDataGenerator {
    static let shared = TestDataGenerator()
    
    // Generate AD test data with immutable array
    func generateADTestData() -> [String] {
        let csvLines = [
            "AD Group,System Account,Application,Suite,OTAP,Critical",
            
            // Valid records with matching HR records
            "A-PALISADE-RISK_PROFESSIONAL-751-X86-P,SOKOOTG,@Risk 7.5,@Risk 7.5,P,N/A",
            "A-PALISADE-RISK_PROFESSIONAL-751-X86-P,SOWKOME,@Risk 7.5,@Risk 7.5,P,N/A",
            "A-BUREAU_WSNP-VTLB_CALCULATOR-X86-P,SZHORS1,202001VTLB Calculator,Calculator,P,N/A",
            "A-BUREAU_WSNP-VTLB_CALCULATOR-X86-P,SZKISTM,202001VTLB Calculator,Calculator,P,N/A",
            
            // AD-only records (no matching HR)
            "A-MICROSOFT-VISIO-X86-P,SOVIS01,Visio,Office 365,P,N/A",
            "A-MICROSOFT-PROJECT-X86-P,SOPRJ01,Project,Office 365,P,N/A",
            
            // Multiple applications per user
            "A-MICROSOFT-OFFICE365-X86-P,SOMULT1,Word,Office 365,P,N/A",
            "A-MICROSOFT-VISIO-X86-P,SOMULT1,Visio,Office 365,P,N/A",
            "A-MICROSOFT-PROJECT-X86-P,SOMULT1,Project,Office 365,P,N/A",
            
            // Critical applications with leave date match
            "A-BUREAU_WSNP-VTLB_CALCULATOR-X86-P,SZLEAV1,202001VTLB Calculator,Calculator,P,YES",
            
            // Invalid records (missing fields)
            "A-PALISADE-RISK_PROFESSIONAL-751-X86-P,,@Risk 7.5,@Risk 7.5,P,N/A",
            ",SOWKOME,@Risk 7.5,@Risk 7.5,P,N/A",
            
            // Duplicate records
            "A-PALISADE-RISK_PROFESSIONAL-751-X86-P,SOKOOTG,@Risk 7.5,@Risk 7.5,P,N/A",
            
            // Different OTAP environments
            "A-PALISADE-RISK_PROFESSIONAL-751-X86-P,SOTEST1,@Risk 7.5,@Risk 7.5,T,N/A",
            "A-PALISADE-RISK_PROFESSIONAL-751-X86-P,SOACC01,@Risk 7.5,@Risk 7.5,A,N/A",
            
            // Multiple OTAP environments for same user
            "A-MICROSOFT-OFFICE365-X86-P,SOOTAP1,Word,Office 365,P,N/A",
            "A-MICROSOFT-OFFICE365-X86-P,SOOTAP1,Word,Office 365,T,N/A",
            "A-MICROSOFT-OFFICE365-X86-P,SOOTAP1,Word,Office 365,A,N/A",
            
            // Critical applications
            "A-BUREAU_WSNP-VTLB_CALCULATOR-X86-P,SZPROD1,202001VTLB Calculator,Calculator,P,YES",
            
            // Different application suites
            "A-MICROSOFT-OFFICE365-X86-P,SOOFF01,Word,Office 365,P,N/A",
            "A-MICROSOFT-OFFICE365-X86-P,SOOFF02,Excel,Office 365,P,N/A",
            "A-MICROSOFT-OFFICE365-X86-P,SOOFF03,PowerPoint,Office 365,P,N/A"
        ]
        
        return csvLines
    }
    
    // Generate HR test data with immutable array
    func generateHRTestData() -> [String] {
        let csvLines = [
            "System Account,Department,Job Role,Division,Leave Date,Employee Number",
            
            // Active employees with matching AD records
            "SOKOOTG,SZW523818 Portefeuille SW - Cluster 1,algemeen ondersteunend medewerker,SZW,,12345",
            "SOWKOME,SZW005350 Informatiebeleid en Strategie,medewerker IV,SZW,,12346",
            "SZHORS1,SZW523870 Centraal Beschut Werk,medewerker II,SZW,,12347",
            "SZKISTM,SZW523870 Centraal Beschut Werk,medewerker I,SZW,,12348",
            
            // HR-only records (no matching AD)
            "SZNEW01,SZW523818 Portefeuille SW - Cluster 1,nieuwe medewerker,SZW,,12360",
            "SZOUT01,SZW005350 Informatiebeleid en Strategie,vertrekkende medewerker,SZW,31-03-2024,12361",
            
            // Multiple applications user
            "SOMULT1,SZW523818 Portefeuille SW - Cluster 1,projectmanager,SZW,,12370",
            
            // Multiple OTAP environments user
            "SOOTAP1,SZW523818 Portefeuille SW - Cluster 1,ontwikkelaar,SZW,,12371",
            
            // Critical application user with leave date
            "SZLEAV1,SZW523870 Centraal Beschut Werk,medewerker II,SZW,31-05-2024,12372",
            
            // Employees with leave date (matching AD)
            "SOTEST1,SZW523818 Portefeuille SW - Cluster 1,algemeen ondersteunend medewerker,SZW,30-06-2024,12349",
            "SOACC01,SZW005350 Informatiebeleid en Strategie,medewerker IV,SZW,31-12-2024,12350",
            
            // Invalid records (missing required fields)
            ",SZW523818 Portefeuille SW - Cluster 1,algemeen ondersteunend medewerker,SZW,,12351",
            "SOOFF01,,medewerker IV,SZW,,12352",
            
            // Different divisions
            "SOOFF02,OCW000123 ICT Support,medewerker III,OCW,,12353",
            "SOOFF03,BZK000456 Infrastructuur,specialist,BZK,,12354",
            
            // Duplicate system accounts
            "SOKOOTG,SZW523818 Portefeuille SW - Cluster 1,algemeen ondersteunend medewerker,SZW,,12355"
        ]
        
        return csvLines
    }
    
    // Verify combined data test scenarios
    func verifyCombinedDataScenarios() -> [String] {
        return [
            "Test Scenario 1: Complete matches (AD + HR)",
            "- SOKOOTG: Active employee with AD access",
            "- SOWKOME: Active employee with AD access",
            "- SZHORS1: Active employee with AD access",
            "- SZKISTM: Active employee with AD access",
            "",
            "Test Scenario 2: AD-only records (no HR match)",
            "- SOVIS01: AD access without HR record",
            "- SOPRJ01: AD access without HR record",
            "",
            "Test Scenario 3: HR-only records (no AD match)",
            "- SZNEW01: HR record without AD access (new employee)",
            "- SZOUT01: HR record without AD access (leaving employee)",
            "",
            "Test Scenario 4: Records with leave dates",
            "- SOTEST1: Has AD access and future leave date",
            "- SOACC01: Has AD access and future leave date",
            "- SZLEAV1: Has critical application and leave date",
            "",
            "Test Scenario 5: Invalid/Incomplete records",
            "- Records with missing System Account",
            "- Records with missing Department",
            "",
            "Test Scenario 6: Cross-division matches",
            "- SOOFF02: AD access with OCW division",
            "- SOOFF03: AD access with BZK division",
            "",
            "Test Scenario 7: Duplicate handling",
            "- SOKOOTG: Appears multiple times in both AD and HR",
            "",
            "Test Scenario 8: Multiple applications per user",
            "- SOMULT1: Has Word, Visio, and Project access",
            "",
            "Test Scenario 9: Multiple OTAP environments",
            "- SOOTAP1: Has P, T, and A environments for same application",
            "",
            "Test Scenario 10: Critical applications with leave dates",
            "- SZLEAV1: Has critical application access and upcoming leave date",
            "",
            "Expected Combined View Behavior:",
            "1. Complete matches should show all information from both sources",
            "2. AD-only records should show AD info with N/A for HR fields",
            "3. HR-only records should show HR info with N/A for AD fields",
            "4. Users with leave dates should be highlighted or marked",
            "5. Multiple applications should be properly grouped",
            "6. Multiple OTAP environments should be clearly displayed",
            "7. Critical applications should be highlighted",
            "8. Cross-division access should be easily identifiable",
            "9. Invalid/incomplete records should be properly handled",
            "10. Duplicate records should be appropriately managed"
        ]
    }
    
    // Save test data to files
    func saveTestDataToFiles() throws {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Save AD test data
        let adTestData = generateADTestData().joined(separator: "\n")
        let adFilePath = documentsPath.appendingPathComponent("ad_test_data.csv")
        try adTestData.write(to: adFilePath, atomically: true, encoding: .utf8)
        
        // Save HR test data
        let hrTestData = generateHRTestData().joined(separator: "\n")
        let hrFilePath = documentsPath.appendingPathComponent("hr_test_data.csv")
        try hrTestData.write(to: hrFilePath, atomically: true, encoding: .utf8)
        
        // Save combined test scenarios
        let combinedScenarios = verifyCombinedDataScenarios().joined(separator: "\n")
        let scenariosFilePath = documentsPath.appendingPathComponent("combined_test_scenarios.txt")
        try combinedScenarios.write(to: scenariosFilePath, atomically: true, encoding: .utf8)
        
        print("Test data files created at:")
        print("AD: \(adFilePath.path)")
        print("HR: \(hrFilePath.path)")
        print("Combined Scenarios: \(scenariosFilePath.path)")
    }
}

// Test scenarios covered:
/*
 AD Test Data Scenarios:
 1. Valid records with different applications
 2. Invalid records with missing fields
 3. Duplicate records
 4. Different OTAP environments (P, T, A)
 5. Critical vs non-critical applications
 6. Multiple applications in the same suite
 7. Multiple applications per user
 8. Multiple OTAP environments per user
 
 HR Test Data Scenarios:
 1. Active employees
 2. Employees with future leave dates
 3. Invalid records with missing fields
 4. Different divisions
 5. Duplicate system accounts
 6. Various job roles and departments
 7. Critical application users with leave dates
 
 Combined Data Testing:
 1. Complete matches: Records present in both AD and HR
 2. AD-only records: System accounts with no HR data
 3. HR-only records: Employees with no AD access
 4. Records with leave dates: Testing future departures
 5. Invalid/Incomplete records in either system
 6. Cross-division matches: Testing different departments
 7. Duplicate handling across both systems
 8. Multiple applications per user handling
 9. Multiple OTAP environments display
 10. Critical applications with leave dates
 */ 