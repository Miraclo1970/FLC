import Foundation

// Represents a single validation rule
struct ValidationRule: Identifiable, Hashable {
    let id = UUID()
    let description: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Represents a complete validation configuration for a data type
struct ValidationConfig: Identifiable {
    let id = UUID()
    let title: String
    let rules: [ValidationRule]
    let requiredFields: [String]
    let optionalFields: [String]
    
    // Helper to create validation rules from strings
    static func createRules(_ descriptions: [String]) -> [ValidationRule] {
        descriptions.map { ValidationRule(description: $0) }
    }
}

// Central validation configuration store
class ValidationConfigStore: ObservableObject {
    @Published private(set) var configurations: [ValidationConfig] = []
    
    static let shared = ValidationConfigStore()
    
    private init() {
        setupDefaultConfigurations()
    }
    
    private func setupDefaultConfigurations() {
        configurations = [
            ValidationConfig(
                title: "AD Data",
                rules: ValidationConfig.createRules([
                    "AD Group is required (cannot be empty or 'N/A')",
                    "System Account is required (cannot be empty or 'N/A')",
                    "Unique combination of AD Group and System Account required"
                ]),
                requiredFields: ["AD Group", "System Account"],
                optionalFields: ["Application Name", "Application Suite", "OTAP", "Critical"]
            ),
            ValidationConfig(
                title: "HR Data",
                rules: ValidationConfig.createRules([
                    "System Account is required (cannot be empty or 'N/A')",
                    "System Account must be unique"
                ]),
                requiredFields: ["System Account"],
                optionalFields: ["Department", "Job Role", "Division", "Leave Date", "Department Simple"]
            ),
            ValidationConfig(
                title: "Package Status",
                rules: ValidationConfig.createRules([
                    "Application Name is required and must be unique",
                    "Package Status is required"
                ]),
                requiredFields: ["Application Name", "Package Status"],
                optionalFields: ["Package Readiness Date"]
            ),
            ValidationConfig(
                title: "Test Status",
                rules: ValidationConfig.createRules([
                    "Application Name is required",
                    "Test Status is required",
                    "Test Date is required",
                    "Test Result is required"
                ]),
                requiredFields: ["Application Name", "Test Status", "Test Date", "Test Result"],
                optionalFields: ["Test Comments"]
            ),
            ValidationConfig(
                title: "Migration",
                rules: ValidationConfig.createRules([
                    "Application Name is required and must be unique",
                    "Application New is required",
                    "Application Suite New is required",
                    "Will Be is required",
                    "In Scope/Out Scope Division is required",
                    "Migration Platform is required",
                    "Migration Application Readiness is required"
                ]),
                requiredFields: [
                    "Application Name",
                    "Application New",
                    "Application Suite New",
                    "Will Be",
                    "In Scope/Out Scope Division",
                    "Migration Platform",
                    "Migration Application Readiness"
                ],
                optionalFields: []
            ),
            ValidationConfig(
                title: "Cluster",
                rules: ValidationConfig.createRules([
                    "Department is required and must match an existing HR Department"
                ]),
                requiredFields: [
                    "Department"
                ],
                optionalFields: [
                    "Department Simple",
                    "Domain",
                    "Migration Cluster",
                    "Migration Cluster Readiness"
                ]
            )
        ]
    }
    
    // Method to add new validation configurations
    func addConfiguration(_ config: ValidationConfig) {
        configurations.append(config)
    }
    
    // Method to update existing validation configurations
    func updateConfiguration(_ config: ValidationConfig) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index] = config
        }
    }
    
    // Method to get validation configuration by title
    func getConfiguration(forTitle title: String) -> ValidationConfig? {
        configurations.first { $0.title == title }
    }
} 