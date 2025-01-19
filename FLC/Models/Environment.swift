import Foundation
import SwiftUI

enum Environment: String, CaseIterable {
    case development = "Development"
    case test = "Test"
    case acceptance = "Acceptance"
    case production = "Production"
    
    static var current: Environment {
        get {
            let defaults = UserDefaults.standard
            if let storedValue = defaults.string(forKey: "current_environment"),
               let environment = Environment(rawValue: storedValue) {
                return environment
            }
            return .development // Default to development
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.rawValue, forKey: "current_environment")
        }
    }
    
    // Base directory for all environment data
    var baseDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "nl.jillten.FLC")?
            .appendingPathComponent("Library/Application Support/FLC", isDirectory: true)
            .appendingPathComponent(rawValue.lowercased(), isDirectory: true)
    }
    
    // Database directory for this environment
    var databaseDirectory: URL? {
        baseDirectory?.appendingPathComponent("db", isDirectory: true)
    }
    
    // Derived data directory for this environment
    var derivedDataDirectory: URL? {
        baseDirectory?.appendingPathComponent("derived", isDirectory: true)
    }
    
    // Database path for this environment
    var databasePath: URL? {
        databaseDirectory?.appendingPathComponent("flc.db")
    }
    
    // Create all necessary directories for this environment
    func createDirectories() throws {
        let fileManager = FileManager.default
        
        // Create base directory
        if let baseDir = baseDirectory {
            try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
        
        // Create database directory
        if let dbDir = databaseDirectory {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }
        
        // Create derived data directory
        if let derivedDir = derivedDataDirectory {
            try fileManager.createDirectory(at: derivedDir, withIntermediateDirectories: true)
        }
    }
    
    // Helper to get a path in the derived data directory
    func derivedDataPath(for filename: String) -> URL? {
        derivedDataDirectory?.appendingPathComponent(filename)
    }
    
    // Display color for the environment
    var displayColor: Color {
        switch self {
        case .development:
            return .blue
        case .test:
            return .orange
        case .acceptance:
            return .green
        case .production:
            return .red
        }
    }
    
    var isProduction: Bool {
        self == .production
    }
} 