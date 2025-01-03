import Foundation

class ImportProgress: ObservableObject {
    enum DataType: String {
        case ad = "AD"
        case hr = "HR"
        case packageStatus = "Package Status"
        case testing = "Testing"
        case migration = "Migration"
        case combined = "Combined"
        case cluster = "Cluster"
    }
    
    @Published var isProcessing = false
    @Published var progressValue: Double = 0.0
    @Published var currentOperation = ""
    @Published var selectedDataType: DataType = .ad
    
    // AD Records
    @Published var validRecords: [ADData] = []
    @Published var invalidRecords: [String] = []
    @Published var duplicateRecords: [String] = []
    
    // HR Records
    @Published var validHRRecords: [HRData] = []
    @Published var invalidHRRecords: [String] = []
    @Published var duplicateHRRecords: [String] = []
    
    // Package Status Records
    @Published var validPackageRecords: [PackageStatusData] = []
    @Published var invalidPackageRecords: [String] = []
    @Published var duplicatePackageRecords: [String] = []
    
    // Test Records
    @Published var validTestRecords: [TestingData] = []
    @Published var invalidTestRecords: [String] = []
    @Published var duplicateTestRecords: [String] = []
    
    // Migration Records
    @Published var validMigrationRecords: [MigrationData] = []
    @Published var invalidMigrationRecords: [String] = []
    @Published var duplicateMigrationRecords: [String] = []
    
    // Cluster Records
    @Published var validClusterRecords: [ClusterData] = []
    @Published var invalidClusterRecords: [String] = []
    @Published var duplicateClusterRecords: [String] = []
    
    func reset() {
        isProcessing = false
        progressValue = 0.0
        currentOperation = ""
        validRecords = []
        invalidRecords = []
        duplicateRecords = []
        validHRRecords = []
        invalidHRRecords = []
        duplicateHRRecords = []
        validPackageRecords = []
        invalidPackageRecords = []
        duplicatePackageRecords = []
        validTestRecords = []
        invalidTestRecords = []
        duplicateTestRecords = []
        validMigrationRecords = []
        invalidMigrationRecords = []
        duplicateMigrationRecords = []
        validClusterRecords = []
        invalidClusterRecords = []
        duplicateClusterRecords = []
    }
    
    func update(operation: String, progress: Double) {
        currentOperation = operation
        progressValue = progress
    }
} 