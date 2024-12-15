import SwiftUI

class ImportProgress: ObservableObject {
    enum DataType {
        case ad
        case hr
        case combined
        case packageStatus
        case testing
    }
    
    @Published var isProcessing: Bool = false
    @Published var currentOperation: String = ""
    @Published var progressValue: Double = 0.0
    @Published var selectedDataType: DataType = .ad
    
    // Validation data for AD
    @Published var validRecords: [ADData] = []
    @Published var invalidRecords: [String] = []
    @Published var duplicateRecords: [String] = []
    
    // Validation data for HR
    @Published var validHRRecords: [HRData] = []
    @Published var invalidHRRecords: [String] = []
    @Published var duplicateHRRecords: [String] = []
    
    // Validation data for package status
    @Published var validPackageRecords: [PackageStatusData] = []
    @Published var invalidPackageRecords: [String] = []
    @Published var duplicatePackageRecords: [String] = []
    
    // Validation data for testing
    @Published var validTestRecords: [TestingData] = []
    @Published var invalidTestRecords: [String] = []
    @Published var duplicateTestRecords: [String] = []
    
    func reset() {
        isProcessing = false
        currentOperation = ""
        progressValue = 0.0
        selectedDataType = .ad  // Reset to AD by default
        // Reset AD data
        validRecords = []
        invalidRecords = []
        duplicateRecords = []
        // Reset HR data
        validHRRecords = []
        invalidHRRecords = []
        duplicateHRRecords = []
        // Reset package status data
        validPackageRecords = []
        invalidPackageRecords = []
        duplicatePackageRecords = []
        // Reset test data
        validTestRecords = []
        invalidTestRecords = []
        duplicateTestRecords = []
    }
    
    func update(operation: String, progress: Double) {
        currentOperation = operation
        progressValue = min(max(progress, 0.0), 1.0)
    }
} 