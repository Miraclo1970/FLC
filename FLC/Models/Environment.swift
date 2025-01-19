import Foundation
import SwiftUI

extension FileManager {
    enum DirectoryError: Error {
        case invalidPath
        case creationFailed
        case deletionFailed
    }
}

enum Environment: String, CaseIterable {
    case development = "Development"
    case test = "Test"
    case acceptance = "Acceptance"
    case production = "Production"
    
    static var defaultEnvironment: Environment {
        #if DEBUG
        return .development
        #elseif TESTING
        return .test
        #elseif ACCEPTANCE
        return .acceptance
        #else
        return .production
        #endif
    }
    
    static var current: Environment {
        get {
            let defaults = UserDefaults.standard
            if let storedValue = defaults.string(forKey: "current_environment"),
               let environment = Environment(rawValue: storedValue) {
                return environment
            }
            return defaultEnvironment
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.rawValue, forKey: "current_environment")
        }
    }
    
    // Base directory for all environment data
    var baseDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "nl.jillten.FLC") else {
            // Fall back to app's support directory if app group is not available
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            return paths.first?.appendingPathComponent("FLC", isDirectory: true)
                       .appendingPathComponent(rawValue.lowercased(), isDirectory: true)
        }
        return containerURL.appendingPathComponent("Library/Application Support/FLC", isDirectory: true)
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
    func createDirectories(basePath: URL? = nil) throws {
        let fileManager = FileManager.default
        let baseDir = basePath ?? baseDirectory
        
        guard let baseDir = baseDir else {
            throw FileManager.DirectoryError.invalidPath
        }
        
        // Create base directory
        do {
            try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        } catch {
            throw FileManager.DirectoryError.creationFailed
        }
        
        // Create database directory
        if let dbDir = databaseDirectory {
            do {
                try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            } catch {
                throw FileManager.DirectoryError.creationFailed
            }
        }
        
        // Create derived data directory
        if let derivedDir = derivedDataDirectory {
            do {
                try fileManager.createDirectory(at: derivedDir, withIntermediateDirectories: true)
            } catch {
                throw FileManager.DirectoryError.creationFailed
            }
        }
    }
    
    // Clean up all directories for this environment
    func cleanupDirectories() throws {
        let fileManager = FileManager.default
        
        // Remove base directory (this will remove all subdirectories as well)
        if let baseDir = baseDirectory, fileManager.fileExists(atPath: baseDir.path) {
            do {
                try fileManager.removeItem(at: baseDir)
            } catch {
                throw FileManager.DirectoryError.deletionFailed
            }
        }
    }
    
    // Migrate old development environment structure to new structure
    func migrateOldDevelopmentStructure() throws {
        guard self == .development else { return }
        let fileManager = FileManager.default
        
        guard let baseDir = baseDirectory,
              let dbDir = databaseDirectory else {
            throw FileManager.DirectoryError.invalidPath
        }
        
        // Create new directory structure
        try createDirectories()
        
        // Check for old database files
        let dbFiles = ["flc.db", "flc.db-shm", "flc.db-wal"]
        for file in dbFiles {
            let oldPath = baseDir.appendingPathComponent(file)
            let newPath = dbDir.appendingPathComponent(file)
            
            if fileManager.fileExists(atPath: oldPath.path) {
                do {
                    try fileManager.moveItem(at: oldPath, to: newPath)
                } catch {
                    throw FileManager.DirectoryError.creationFailed
                }
            }
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