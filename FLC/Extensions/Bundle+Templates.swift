import Foundation

extension Bundle {
    func templateURL(for type: ImportView.ImportType) -> URL? {
        let fileName: String
        switch type {
        case .ad:
            fileName = "AD_template"
        case .hr:
            fileName = "HR_template"
        case .packageStatus:
            fileName = "PackageStatus_template"
        case .testing:
            fileName = "TestStatus_template"
        case .migration:
            fileName = "Migration_template"
        }
        
        print("\n=== Template Search Debug ===")
        print("Looking for template: \(fileName).xlsx")
        
        // Get the project directory path
        let projectDir = bundlePath.components(separatedBy: "DerivedData").first ?? ""
        let templatePath = (projectDir as NSString).appendingPathComponent("FLC/Templates/\(fileName).xlsx")
        
        print("Trying project directory path: \(templatePath)")
        if FileManager.default.fileExists(atPath: templatePath) {
            print("Found template at project path!")
            return URL(fileURLWithPath: templatePath)
        }
        
        // Try bundle paths as fallback
        let possiblePaths = [
            ("Templates", fileName),
            (nil, "Templates/\(fileName)"),
            ("FLC/Templates", fileName)
        ]
        
        for (directory, name) in possiblePaths {
            if let url = url(forResource: name, withExtension: "xlsx", subdirectory: directory) {
                print("Found template in bundle at: \(url.path)")
                return url
            }
        }
        
        print("=== Template Search Failed ===\n")
        return nil
    }
} 