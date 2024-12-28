import SwiftUI
import UniformTypeIdentifiers
import CoreXLSX

struct ImportView: View {
    @State private var showFileImporter = false
    @State private var message = "Select type of data to import"
    @State private var importType: ImportType?
    @EnvironmentObject private var progress: ImportProgress
    @Environment(\.dismiss) var dismiss
    
    enum ImportType {
        case hr
        case ad
        case packageStatus
        case testing
        case migration
        case cluster
    }
    
    private enum DataTypeValidationError: Error {
        case mismatch(expected: ImportType, detected: ImportType)
        
        var description: String {
            switch self {
            case .mismatch(let expected, let detected):
                return "Data type mismatch: You selected to import \(expected) data but the file appears to contain \(detected) data. Please select the correct import type."
            }
        }
    }
    
    private func detectDataType(_ headers: [String]) -> ImportType? {
        // Check first row for explicit type marker
        let firstRow = headers.joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces)
        
        if firstRow.contains("hr") {
            return .hr
        } else if firstRow.contains("ad") {
            return .ad
        } else if firstRow.contains("package status") {
            return .packageStatus
        } else if firstRow.contains("test status") {
            return .testing
        } else if firstRow.contains("migration") || firstRow.contains("platform") {
            return .migration
        } else if firstRow.contains("cluster") || firstRow.contains("department") {
            return .cluster
        }
        
        return nil
    }

    private func validateDataType(_ headers: [String], expected: ImportType) throws {
        guard let detectedType = detectDataType(headers) else {
            // Instead of proceeding with caution, we should throw an error if we can't detect the type
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not determine data type from headers. Please check if the file contains the correct headers."])
        }
        
        if detectedType != expected {
            throw DataTypeValidationError.mismatch(expected: expected, detected: detectedType)
        }
    }
    
    private func openTemplate(type: ImportType) {
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
            fileName = "MigrationStatus_template"
        case .cluster:
            fileName = "Cluster_template"
        }
        
        // First try to find the template in the bundle
        if let templateURL = Bundle.main.url(forResource: fileName, withExtension: "xlsx") {
            NSWorkspace.shared.open(templateURL)
        } else {
            print("Template not found in bundle: \(fileName)")
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import Data")
                .font(.title)
            
            Text(message)
                .foregroundColor(message.contains("Error") ? .red : .secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            if !progress.isProcessing {
                VStack(spacing: 16) {
                    // Template buttons
                    HStack(spacing: 20) {
                        Button("Open AD Template") {
                            openTemplate(type: .ad)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open HR Template") {
                            openTemplate(type: .hr)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open Package Status Template") {
                            openTemplate(type: .packageStatus)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open Test Status Template") {
                            openTemplate(type: .testing)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open Migration Template") {
                            openTemplate(type: .migration)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open Cluster Template") {
                            openTemplate(type: .cluster)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.bottom, 8)
                    
                    // Import buttons
                    VStack(spacing: 8) {
                        Button("Import AD Data") {
                            importType = .ad
                            showFileImporter = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        
                        Button("Import HR Data") {
                            importType = .hr
                            showFileImporter = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        
                        Button("Import Package Status") {
                            importType = .packageStatus
                            showFileImporter = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        
                        Button("Import Test Status") {
                            importType = .testing
                            showFileImporter = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        
                        Button("Import Migration Data") {
                            importType = .migration
                            showFileImporter = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        
                        Button("Import Cluster Data") {
                            importType = .cluster
                            showFileImporter = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .foregroundColor(Color(.windowBackgroundColor))
                                .frame(width: geometry.size.width, height: 8)
                            
                            Rectangle()
                                .foregroundColor(.blue)
                                .frame(width: max(0, geometry.size.width * CGFloat(progress.progressValue)), height: 8)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)
                    .padding(.horizontal)
                    
                    // Progress percentage
                    Text("\(Int(progress.progressValue * 100))%")
                        .font(.headline)
                    
                    // Current operation
                    Text(progress.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 300)
                .padding()
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "xlsx")!],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result)
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        // Reset state
        await MainActor.run {
            progress.reset()
            progress.isProcessing = true
            message = "Preparing import..."
        }
        
        do {
            switch result {
            case .success(let files):
                guard let file = files.first else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])
                }
                
                await MainActor.run {
                    progress.update(operation: "Accessing file...", progress: 0.05)
                }
                
                guard file.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied to access file"])
                }
                
                defer {
                    file.stopAccessingSecurityScopedResource()
                }
                
                await MainActor.run {
                    progress.update(operation: "Opening Excel file...", progress: 0.1)
                }
                
                let filePath = file.path(percentEncoded: false)
                guard let xlsx = XLSXFile(filepath: filePath) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not open Excel file"])
                }
                
                switch importType {
                case .ad:
                    let (valid, invalid, duplicates) = try await processADData(xlsx)
                    await MainActor.run {
                        print("Setting AD records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        progress.selectedDataType = .ad
                        progress.validRecords = valid
                        progress.invalidRecords = invalid
                        progress.duplicateRecords = duplicates
                        message = "Successfully processed AD data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed AD records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        // Dismiss this view to return to the main navigation
                        dismiss()
                    }
                    
                case .hr:
                    let (valid, invalid, duplicates) = try await processHRData(xlsx)
                    await MainActor.run {
                        print("Setting HR records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        progress.selectedDataType = .hr  // Set this before setting the records
                        progress.validHRRecords = valid
                        progress.invalidHRRecords = invalid
                        progress.duplicateHRRecords = duplicates
                        message = "Successfully processed HR data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed HR records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        // Dismiss this view to return to the main navigation
                        dismiss()
                    }
                    
                case .packageStatus:
                    let (valid, invalid, duplicates) = try await processPackageStatusData(xlsx)
                    await MainActor.run {
                        // First set the data type
                        progress.selectedDataType = .packageStatus
                        
                        // Then update the records
                        progress.validPackageRecords = []  // Clear existing records
                        progress.invalidPackageRecords = []
                        progress.duplicatePackageRecords = []
                        
                        // Now set the new records
                        progress.validPackageRecords = valid
                        progress.invalidPackageRecords = invalid
                        progress.duplicatePackageRecords = duplicates
                        
                        message = "Successfully processed Package Status data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed Package Status records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        
                        // Dismiss to return to validation view
                        dismiss()
                    }
                    
                case .testing:
                    let (valid, invalid, duplicates) = try await processTestData(xlsx)
                    await MainActor.run {
                        print("Setting Test Status records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        progress.selectedDataType = .testing
                        progress.validTestRecords = valid
                        progress.invalidTestRecords = invalid
                        progress.duplicateTestRecords = duplicates
                        message = "Successfully processed Test Status data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed Test Status records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        // Dismiss this view to return to the main navigation
                        dismiss()
                    }
                    
                case .migration:
                    let (valid, _, _) = try await processMigrationData(xlsx)
                    await MainActor.run {
                        print("Setting Migration records - Valid: \(valid.count)")
                        progress.selectedDataType = .migration
                        progress.validMigrationRecords = valid
                        message = "Successfully processed Migration data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed Migration records - Valid: \(valid.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        // Dismiss this view to return to the main navigation
                        dismiss()
                    }
                    
                case .cluster:
                    let (valid, invalid, duplicates) = try await processClusterData(xlsx)
                    await MainActor.run {
                        print("Setting Cluster records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        progress.selectedDataType = .cluster
                        progress.validClusterRecords = valid
                        progress.invalidClusterRecords = invalid
                        progress.duplicateClusterRecords = duplicates
                        message = "Successfully processed Cluster data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed Cluster records - Valid: \(valid.count), Invalid: \(invalid.count), Duplicates: \(duplicates.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        // Dismiss this view to return to the main navigation
                        dismiss()
                    }
                    
                case .none:
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No import type selected"])
                }
                
            case .failure(let error):
                throw error
            }
        } catch {
            await MainActor.run {
                if let dataTypeError = error as? DataTypeValidationError {
                    message = "Warning: \(dataTypeError.description)"
                } else {
                    message = "Error: \(error.localizedDescription)"
                }
                progress.isProcessing = false
            }
        }
    }
    
    private func processADData(_ xlsx: XLSXFile) async throws -> (valid: [ADData], invalid: [String], duplicates: [String]) {
        // Initial setup and Excel reading phase (0-40%)
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Initializing...", progress: 0.05)
        }
        
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        guard let path = worksheetPaths.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheets found"])
        }
        
        let worksheet = try xlsx.parseWorksheet(at: path)
        let sharedStrings = try xlsx.parseSharedStrings()
        
        // Get headers for validation
        if let firstRow = worksheet.data?.rows.first {
            let headers = firstRow.cells.map { cell -> String in
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    return sharedStrings.items[stringIndex].text ?? ""
                }
                return cell.value ?? ""
            }
            
            // Validate data type
            try validateDataType(headers, expected: .ad)
        }
        
        // Worksheet loading phase (40-60%)
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Loading worksheet data...", progress: 0.40)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Preparing data structures...", progress: 0.55)
        }
        
        // Header analysis phase (60-70%)
        await MainActor.run {
            progress.update(operation: "Phase 3/5: Analyzing worksheet format...", progress: 0.60)
        }
        
        var validRecords: [ADData] = []
        var invalidRecords: [String] = []
        var duplicateRecords: [String] = []
        var seenRecords = Set<String>() // Track unique combinations
        
        // Process rows
        let rows = worksheet.data?.rows ?? []
        var columnMap: [String: Int] = [:]
        
        await MainActor.run {
            progress.update(operation: "Phase 3/5: Searching for data start marker...", progress: 0.65)
        }
        
        // Process data rows
        var headerRowIndex = -1
        var startDataIndex = -1
        
        // Find the start marker and header indices
        for (index, row) in rows.enumerated() {
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                // Safely handle column reference
                let columnIndex: Int
                let columnString = cell.reference.column.value
                columnIndex = columnString.excelColumnToIndex()
                
                return (index: columnIndex, value: cellValue)
            }
            
            // Calculate the maximum column index needed
            let maxColumnIndex = max(
                rowContent.map { $0.index }.max() ?? 0,
                50  // Minimum size to ensure we have enough space
            )
            
            // Create array with sufficient size
            var fullRowContent: [String] = Array(repeating: "N/A", count: maxColumnIndex + 1)
            
            // Safely populate the array
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                } else {
                    print("WARNING: Column index \(cell.index) exceeds array size \(fullRowContent.count)")
                }
            }
            
            if startDataIndex == -1 {
                let rowText = fullRowContent.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                if rowText.contains("=startdatabelow=") || 
                   rowText.contains("===startdatabelow===") ||
                   rowText.contains("start data below") {
                    startDataIndex = index
                }
            } else if headerRowIndex == -1 {
                // Check for header row
                let headerVariations = ["AD Group", "ADGroup", "AD-Group", "AD_Group", "Group"]
                let foundHeader = fullRowContent.contains { content in
                    let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                    return headerVariations.contains { variation in
                        normalizedContent == variation.lowercased()
                    }
                }
                
                if foundHeader {
                    headerRowIndex = index
                    // Map column headers
                    for (colIndex, header) in fullRowContent.enumerated() {
                        let normalizedHeader = header.trimmingCharacters(in: .whitespaces)
                        let standardHeader: String
                        switch normalizedHeader.lowercased() {
                        case "ad group", "adgroup", "ad-group", "ad_group", "group":
                            standardHeader = "AD Group"
                        case "system account", "systemaccount", "system-account", "system_account", "account":
                            standardHeader = "System Account"
                        case "application name", "applicationname", "application-name", "application_name", "app name", "app":
                            standardHeader = "Application Name"
                        case "application suite", "applicationsuite", "application-suite", "application_suite", "suite":
                            standardHeader = "Application Suite"
                        case "otap", "environment", "env":
                            standardHeader = "OTAP"
                        case "critical", "is critical", "iscritical":
                            standardHeader = "Critical"
                        default:
                            standardHeader = normalizedHeader
                        }
                        columnMap[standardHeader] = colIndex
                    }
                }
            }
            
            if startDataIndex != -1 && headerRowIndex != -1 {
                break
            }
        }
        
        guard startDataIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find '===START DATA BELOW===' marker"])
        }
        
        guard headerRowIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find header row with 'AD Group' column after start marker"])
        }
        
        // Process only the rows after the header
        let dataRows = rows.dropFirst(headerRowIndex + 1)
        let totalRows = dataRows.count
        
        await MainActor.run {
            progress.update(operation: "Phase 4/5: Found \(totalRows) rows to process...", progress: 0.72)
        }
        
        var processedValidRows = 0
        var processedInvalidRows = 0
        var processedDuplicateRows = 0  // Changed from let to var since we need to modify it
        
        for (index, row) in dataRows.enumerated() {
            // Update progress more frequently for data processing
            if index % 50 == 0 {
                let progressValue = 0.72 + (0.18 * Double(index) / Double(max(1, totalRows)))
                let stats = """
                Phase 4/5: Processing rows...
                Row: \(index) of \(totalRows)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                """
                await MainActor.run {
                    progress.update(operation: stats, progress: progressValue)
                }
            }
            
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                // Safely handle column reference
                let columnIndex: Int
                let columnString = cell.reference.column.value
                columnIndex = columnString.excelColumnToIndex()
                
                return (index: columnIndex, value: cellValue)
            }
            
            // Calculate the maximum column index needed
            let maxColumnIndex = max(
                rowContent.map { $0.index }.max() ?? 0,
                50  // Minimum size to ensure we have enough space
            )
            
            // Create array with sufficient size
            var fullRowContent: [String] = Array(repeating: "N/A", count: maxColumnIndex + 1)
            
            // Safely populate the array
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                } else {
                    print("WARNING: Column index \(cell.index) exceeds array size \(fullRowContent.count)")
                }
            }
            
            // Skip completely empty rows
            if fullRowContent.allSatisfy({ $0 == "N/A" }) {
                print("Skipping empty row at index \(index)")
                continue
            }
            
            // Get values using column map
            let adGroup = fullRowContent[safe: columnMap["AD Group"] ?? -1] ?? "N/A"
            let systemAccount = fullRowContent[safe: columnMap["System Account"] ?? -1] ?? "N/A"
            let applicationName = fullRowContent[safe: columnMap["Application Name"] ?? -1] ?? "N/A"
            let applicationSuite = fullRowContent[safe: columnMap["Application Suite"] ?? -1] ?? "N/A"
            let otap = fullRowContent[safe: columnMap["OTAP"] ?? -1] ?? "N/A"
            let critical = fullRowContent[safe: columnMap["Critical"] ?? -1] ?? "N/A"
            
            // Debug column mapping
            if index == 0 || index % 10000 == 0 {
                print("Column Map: \(columnMap)")
                print("Row \(index) values - AD Group: \(adGroup), System Account: \(systemAccount)")
            }
            
            // Create and validate record
            let record = ADData(
                adGroup: adGroup,
                systemAccount: systemAccount,
                applicationName: applicationName,
                applicationSuite: applicationSuite,
                otap: otap,
                critical: critical
            )
            
            if record.isValid {
                let recordId = "\(adGroup)|\(systemAccount)"
                if seenRecords.contains(recordId) {
                    print("Found duplicate at row \(index): \(recordId)")
                    duplicateRecords.append("Row \(index): Duplicate combination of AD Group '\(adGroup)' and System Account '\(systemAccount)'")
                    processedDuplicateRows += 1
                } else {
                    seenRecords.insert(recordId)
                    validRecords.append(record)
                    processedValidRows += 1
                }
            } else {
                print("Found invalid record at row \(index): \(record.validationErrors)")
                invalidRecords.append("Row \(index): \(record.validationErrors.joined(separator: ", "))")
                processedInvalidRows += 1
            }
            
            // Log progress for every 10000 records
            if index % 10000 == 0 {
                print("""
                Processing progress:
                Row: \(index)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                Total processed: \(processedValidRows + processedInvalidRows + processedDuplicateRows)
                """)
            }
        }
        
        // Finalization phase (90-100%)
        await MainActor.run {
            progress.update(operation: "Phase 5/5: Organizing results...", progress: 0.90)
        }
        
        let summary = """
        Phase 5/5: Finalizing import...
        Total processed: \(totalRows)
        Valid records: \(processedValidRows)
        Invalid records: \(processedInvalidRows)
        Duplicate records: \(processedDuplicateRows)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 0.95)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 5/5: Import complete!", progress: 1.0)
        }
        
        return (validRecords, invalidRecords, duplicateRecords)
    }
    
    private func processHRData(_ xlsx: XLSXFile) async throws -> (valid: [HRData], invalid: [String], duplicates: [String]) {
        // Initial setup and Excel reading phase (0-40%)
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Initializing...", progress: 0.05)
        }
        
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        guard let path = worksheetPaths.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheets found"])
        }
        
        // Worksheet loading phase
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Loading worksheet data...", progress: 0.40)
        }
        
        let worksheet = try xlsx.parseWorksheet(at: path)
        let sharedStrings = try xlsx.parseSharedStrings()
        
        // Get headers for validation
        if let firstRow = worksheet.data?.rows.first {
            let headers = firstRow.cells.map { cell -> String in
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    return sharedStrings.items[stringIndex].text ?? ""
                }
                return cell.value ?? ""
            }
            
            print("HR Import - Headers found: \(headers)")
            // Validate data type using the same method as AD validation
            try validateDataType(headers, expected: .hr)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Preparing data structures...", progress: 0.55)
        }
        
        var validRecords: [HRData] = []
        var invalidRecords: [String] = []
        var duplicateRecords: [String] = []
        var seenRecords = Set<String>() // Track unique combinations
        
        let rows = worksheet.data?.rows ?? []
        var columnMap: [String: Int] = [:]
        
        // Process data rows
        var headerRowIndex = -1
        var startDataIndex = -1
        
        // Find the start marker and header indices
        for (index, row) in rows.enumerated() {
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    cellValue = sharedStrings.items[stringIndex].text ?? ""
                } else {
                    cellValue = cell.value ?? ""
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
            for cell in rowContent {
                fullRowContent[cell.index] = cell.value
            }
            
            if startDataIndex == -1 {
                let rowText = fullRowContent.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                if rowText.contains("=startdatabelow=") || 
                   rowText.contains("===startdatabelow===") ||
                   rowText.contains("start data below") {
                    startDataIndex = index
                }
            } else if headerRowIndex == -1 {
                // Check for header row
                let headerVariations = ["System Account", "SystemAccount", "System-Account", "System_Account", "Account"]
                let foundHeader = fullRowContent.contains { content in
                    let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                    return headerVariations.contains { variation in
                        normalizedContent == variation.lowercased()
                    }
                }
                
                if foundHeader {
                    headerRowIndex = index
                    // Map column headers
                    for (colIndex, header) in fullRowContent.enumerated() {
                        let normalizedHeader = header.trimmingCharacters(in: .whitespaces)
                        let standardHeader: String
                        switch normalizedHeader.lowercased() {
                        case "system account", "systemaccount", "system-account", "system_account", "account":
                            standardHeader = "System Account"
                        case "department", "dept":
                            standardHeader = "Department"
                        case "job role", "jobrole", "job-role", "job_role", "role":
                            standardHeader = "Job Role"
                        case "division", "div":
                            standardHeader = "Division"
                        case "leave date", "leavedate", "leave-date", "leave_date":
                            print("Found Leave Date column at index \(colIndex)")
                            standardHeader = "Leave Date"
                        case "department simple", "departmentsimple", "department-simple", "department_simple", "simple department":
                            standardHeader = "Department Simple"
                        default:
                            standardHeader = normalizedHeader
                        }
                        columnMap[standardHeader] = colIndex
                    }
                    
                    // Debug print column map
                    print("Column Map after header processing:")
                    for (header, index) in columnMap {
                        print("\(header): \(index)")
                    }
                }
            }
            
            if startDataIndex != -1 && headerRowIndex != -1 {
                break
            }
        }
        
        guard startDataIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find '===START DATA BELOW===' marker"])
        }
        
        guard headerRowIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find header row with 'System Account' column after start marker"])
        }
        
        // Process only the rows after the header
        let dataRows = rows.dropFirst(headerRowIndex + 1)
        let totalRows = dataRows.count
        
        await MainActor.run {
            progress.update(operation: "Phase 4/5: Found \(totalRows) rows to process...", progress: 0.72)
        }
        
        var processedValidRows = 0
        var processedInvalidRows = 0
        var processedDuplicateRows = 0  // Changed from let to var since we need to modify it
        
        for (index, row) in dataRows.enumerated() {
            if index % 50 == 0 {
                let progressValue = 0.72 + (0.18 * Double(index) / Double(max(1, totalRows)))
                let stats = """
                Phase 4/5: Processing rows...
                Row: \(index) of \(totalRows)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                """
                await MainActor.run {
                    progress.update(operation: stats, progress: progressValue)
                }
            }
            
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    cellValue = sharedStrings.items[stringIndex].text ?? ""
                } else {
                    cellValue = cell.value ?? ""
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
            for cell in rowContent {
                fullRowContent[cell.index] = cell.value
            }
            
            if fullRowContent.allSatisfy({ $0 == "N/A" }) {
                print("Skipping empty row at index \(index)")
                continue
            }
            
            let systemAccount = fullRowContent[safe: columnMap["System Account"] ?? -1] ?? "N/A"
            let department = fullRowContent[safe: columnMap["Department"] ?? -1] != "N/A" ? fullRowContent[safe: columnMap["Department"] ?? -1] : nil
            let jobRole = fullRowContent[safe: columnMap["Job Role"] ?? -1] != "N/A" ? fullRowContent[safe: columnMap["Job Role"] ?? -1] : nil
            let division = fullRowContent[safe: columnMap["Division"] ?? -1] != "N/A" ? fullRowContent[safe: columnMap["Division"] ?? -1] : nil
            let leaveDateStr = fullRowContent[safe: columnMap["Leave Date"] ?? -1] != "N/A" ? fullRowContent[safe: columnMap["Leave Date"] ?? -1] : nil
            let departmentSimple = fullRowContent[safe: columnMap["Department Simple"] ?? -1] != "N/A" ? fullRowContent[safe: columnMap["Department Simple"] ?? -1] : nil

            print("Row \(index) values - System Account: \(systemAccount)")
            
            // Parse leave date if present
            var leaveDate: Date? = nil
            if let leaveDateStr = leaveDateStr {
                print("Row \(index) - Attempting to parse leave date: '\(leaveDateStr)'")
                // Try standard format first
                if let date = DateFormatter.hrDateFormatter.date(from: leaveDateStr) {
                    print("Row \(index) - Successfully parsed leave date with standard format: \(date)")
                    leaveDate = date
                } else if let date = DateFormatter.hrDateParser.date(from: leaveDateStr) {
                    print("Row \(index) - Successfully parsed leave date with alternative format: \(date)")
                    leaveDate = date
                } else if let serialNumber = Double(leaveDateStr) {
                    // Handle Excel serial date
                    // Excel dates are number of days since 1900-01-01, but we need to adjust for Excel's leap year bug
                    let excelEpoch = DateComponents(year: 1899, month: 12, day: 30)
                    if let excelBaseDate = Calendar.current.date(from: excelEpoch) {
                        leaveDate = Calendar.current.date(byAdding: .day, value: Int(serialNumber), to: excelBaseDate)
                        if let parsedDate = leaveDate {
                            print("Row \(index) - Successfully parsed Excel serial date: \(DateFormatter.hrDateFormatter.string(from: parsedDate))")
                        }
                    }
                } else {
                    print("Row \(index) - Failed to parse leave date: '\(leaveDateStr)' with all formats")
                }
            }
            
            let record = HRData(
                systemAccount: systemAccount,
                department: department,
                jobRole: jobRole,
                division: division,
                leaveDate: leaveDate,
                departmentSimple: departmentSimple
            )
            
            if record.isValid {
                if seenRecords.contains(systemAccount) {
                    print("Found duplicate at row \(index): \(systemAccount)")
                    duplicateRecords.append("Row \(index): Duplicate System Account '\(systemAccount)'")
                    processedDuplicateRows += 1
                } else {
                    seenRecords.insert(systemAccount)
                    validRecords.append(record)
                    processedValidRows += 1
                }
            } else {
                print("Found invalid record at row \(index): \(record.validationErrors)")
                invalidRecords.append("Row \(index): \(record.validationErrors.joined(separator: ", "))")
                processedInvalidRows += 1
            }
            
            if index % 10000 == 0 {
                print("""
                Processing progress:
                Row: \(index)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                Total processed: \(processedValidRows + processedInvalidRows + processedDuplicateRows)
                """)
            }
        }
        
        // Finalization phase
        await MainActor.run {
            progress.update(operation: "Phase 5/5: Organizing results...", progress: 0.90)
        }
        
        let summary = """
        Phase 5/5: Finalizing import...
        Total processed: \(totalRows)
        Valid records: \(processedValidRows)
        Invalid records: \(processedInvalidRows)
        Duplicate records: \(processedDuplicateRows)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 0.95)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 5/5: Import complete!", progress: 1.0)
        }
        
        return (validRecords, invalidRecords, duplicateRecords)
    }
    
    private func processPackageStatusData(_ xlsx: XLSXFile) async throws -> ([PackageStatusData], [String], [String]) {
        var validRecords: [PackageStatusData] = []
        var invalidRecords: [String] = []
        var duplicateRecords: [String] = []
        var seenApplicationNames = Set<String>()
        
        do {
            await MainActor.run {
                progress.update(operation: "Phase 1/5: Opening worksheet...", progress: 0.1)
            }
            
            print("Attempting to parse worksheet paths...")
            let worksheetPaths = try xlsx.parseWorksheetPaths()
            print("Found \(worksheetPaths.count) worksheet paths")
            
            guard let path = worksheetPaths.first else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheets found"])
            }
            print("Using worksheet path: \(path)")
            
            print("Attempting to parse worksheet...")
            let worksheet = try xlsx.parseWorksheet(at: path)
            print("Successfully parsed worksheet")
            
            print("Attempting to parse shared strings...")
            let sharedStrings = try xlsx.parseSharedStrings()
            print("Successfully parsed shared strings")
            
            let rows = worksheet.data?.rows ?? []
            print("Found \(rows.count) rows in worksheet")
            
            // Get headers for validation
            guard let firstRow = worksheet.data?.rows.first else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No rows found in worksheet"])
            }
            
            print("Processing first row with \(firstRow.cells.count) cells")
            let headers = try firstRow.cells.enumerated().map { (index, cell) -> String in
                do {
                    if let sharedStrings = sharedStrings,
                       case .sharedString = cell.type,
                       let value = cell.value,
                       let stringIndex = Int(value) {
                        print("Processing header cell \(index): type=\(String(describing: cell.type)), value=\(value), stringIndex=\(stringIndex)")
                        guard stringIndex < sharedStrings.items.count else {
                            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid shared string index: \(stringIndex), max: \(sharedStrings.items.count)"])
                        }
                        return sharedStrings.items[stringIndex].text ?? ""
                    }
                    print("Processing regular header cell \(index): type=\(String(describing: cell.type)), value=\(String(describing: cell.value))")
                    return cell.value ?? ""
                } catch {
                    print("Error processing header cell \(index): \(error)")
                    throw error
                }
            }
            
            print("Found headers: \(headers)")
            
            // Validate data type
            try validateDataType(headers, expected: .packageStatus)
            
            // Find the start marker and header row
            var headerRowIndex = -1
            var startDataIndex = -1
            var columnMap: [String: Int] = [:]
            
            // Process each row to find start marker and headers
            for (index, row) in (worksheet.data?.rows ?? []).enumerated() {
                let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                    let cellValue: String
                    if let sharedStrings = sharedStrings,
                       case .sharedString = cell.type,
                       let value = cell.value,
                       let stringIndex = Int(value),
                       stringIndex < sharedStrings.items.count {
                        let text = sharedStrings.items[stringIndex].text ?? ""
                        cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                    } else {
                        let value = cell.value ?? ""
                        cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                    }
                    
                    let columnIndex = cell.reference.column.value.excelColumnToIndex()
                    print("Column reference: \(cell.reference.column.value), index: \(columnIndex)")
                    return (index: columnIndex, value: cellValue)
                }
                
                // Calculate the maximum column index needed
                let maxColumnIndex = max(
                    columnMap.values.max() ?? 19,
                    rowContent.map { $0.index }.max() ?? 19
                )
                
                // Create array with sufficient size
                var fullRowContent: [String] = Array(repeating: "N/A", count: maxColumnIndex + 1)
                
                // Safely populate the array
                for cell in rowContent {
                    if cell.index < fullRowContent.count {
                        fullRowContent[cell.index] = cell.value
                    } else {
                        print("WARNING: Skipping cell with index \(cell.index) as it exceeds array size \(fullRowContent.count)")
                    }
                }
                
                if startDataIndex == -1 {
                    let rowText = fullRowContent.joined(separator: " ")
                        .trimmingCharacters(in: .whitespaces)
                        .lowercased()
                        .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                    if rowText.contains("=startdatabelow=") || 
                       rowText.contains("===startdatabelow===") ||
                       rowText.contains("start data below") {
                        startDataIndex = index
                    }
                } else if headerRowIndex == -1 {
                    // Check for header row
                    let headerVariations = ["Application Name", "ApplicationName", "Application-Name", "Application_Name", "App Name"]
                    let foundHeader = fullRowContent.contains { content in
                        let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                        return headerVariations.contains { variation in
                            normalizedContent == variation.lowercased()
                        }
                    }
                    
                    if foundHeader {
                        headerRowIndex = index
                        // Map column headers
                        for (colIndex, header) in fullRowContent.enumerated() {
                            let normalizedHeader = header.trimmingCharacters(in: .whitespaces)
                            print("Processing header: '\(normalizedHeader)'")
                            let standardHeader: String
                            switch normalizedHeader.lowercased() {
                            case "application name", "applicationname":
                                standardHeader = "Application Name"
                            case "package status", "packagestatus":
                                standardHeader = "Package Status"
                            case "package readiness date", "packagereadinessdate":
                                standardHeader = "Readiness Date"
                            default:
                                standardHeader = normalizedHeader
                                print("Unmatched header: '\(normalizedHeader)' -> '\(standardHeader)'")
                            }
                            columnMap[standardHeader] = colIndex
                            print("Mapped '\(normalizedHeader)' to '\(standardHeader)' at index \(colIndex)")
                        }
                        
                        print("Final Column Map:")
                        for (header, index) in columnMap {
                            print("\(header): \(index)")
                        }
                    }
                }
                
                if startDataIndex != -1 && headerRowIndex != -1 {
                    break
                }
            }
            
            guard startDataIndex != -1 else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find '===START DATA BELOW===' marker"])
            }
            
            guard headerRowIndex != -1 else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find header row with required columns"])
            }
            
            // Process only the rows after the header
            let dataRows = rows.dropFirst(headerRowIndex + 1)
            let totalRows = dataRows.count
            
            await MainActor.run {
                progress.update(operation: "Phase 4/5: Found \(totalRows) rows to process...", progress: 0.72)
            }
            
            var processedValidRows = 0
            var processedInvalidRows = 0
            var processedDuplicateRows = 0
            
            for (index, row) in dataRows.enumerated() {
                if index % 50 == 0 {
                    let progressValue = 0.72 + (0.18 * Double(index) / Double(max(1, totalRows)))
                    let stats = """
                    Phase 4/5: Processing rows...
                    Row: \(index) of \(totalRows)
                    Valid: \(processedValidRows)
                    Invalid: \(processedInvalidRows)
                    Duplicates: \(processedDuplicateRows)
                    """
                    await MainActor.run {
                        progress.update(operation: stats, progress: progressValue)
                    }
                }
                
                let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                    let cellValue: String
                    if let sharedStrings = sharedStrings,
                       case .sharedString = cell.type,
                       let value = cell.value,
                       let stringIndex = Int(value),
                       stringIndex < sharedStrings.items.count {
                        let text = sharedStrings.items[stringIndex].text ?? ""
                        cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                    } else {
                        let value = cell.value ?? ""
                        cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                    }
                    
                    let columnIndex = cell.reference.column.value.excelColumnToIndex()
                    return (index: columnIndex, value: cellValue)
                }
                
                var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
                for cell in rowContent {
                    fullRowContent[cell.index] = cell.value
                }
                
                // Skip empty rows
                if fullRowContent.allSatisfy({ $0 == "N/A" }) {
                    print("Skipping empty row at index \(index)")
                    continue
                }
                
                let applicationName = fullRowContent[safe: columnMap["Application Name"] ?? -1] ?? "N/A"
                let packageStatus = fullRowContent[safe: columnMap["Package Status"] ?? -1] ?? "N/A"
                let readinessDateStr = fullRowContent[safe: columnMap["Readiness Date"] ?? -1]
                
                print("Row \(index + 1) raw values:")
                print("- Application Name: '\(applicationName)'")
                print("- Package Status: '\(packageStatus)'")
                print("- Readiness Date: '\(readinessDateStr.map { "'\($0)'" } ?? "nil")'")
                
                // Parse readiness date
                var readinessDate: Date? = nil
                if let dateStr = readinessDateStr, dateStr != "N/A" {
                    print("Attempting to parse date: '\(dateStr)'")
                    // Try different date formats
                    let dateFormatters = [
                        DateFormatter.hrDateFormatter,
                        DateFormatter.hrDateParser
                    ]
                    
                    for formatter in dateFormatters {
                        if let date = formatter.date(from: dateStr) {
                            readinessDate = date
                            print("Successfully parsed date with formatter: \(date)")
                            break
                        }
                    }
                    
                    // Try Excel serial date if other formats fail
                    if readinessDate == nil, let serialNumber = Double(dateStr) {
                        print("Attempting to parse Excel serial date: \(serialNumber)")
                        let excelEpoch = DateComponents(year: 1899, month: 12, day: 30)
                        if let excelBaseDate = Calendar.current.date(from: excelEpoch) {
                            readinessDate = Calendar.current.date(byAdding: .day, value: Int(serialNumber), to: excelBaseDate)
                            if let date = readinessDate {
                                print("Successfully parsed Excel serial date: \(date)")
                            }
                        }
                    }
                    
                    if readinessDate == nil {
                        print("Failed to parse date: '\(dateStr)'")
                    }
                }
                
                let record = PackageStatusData(
                    id: nil,
                    applicationName: applicationName,
                    packageStatus: packageStatus,
                    packageReadinessDate: readinessDate,
                    importDate: Date(),
                    importSet: "Import_\(DateFormatter.hrDateFormatter.string(from: Date()))"
                )
                
                print("\nValidating record at row \(index + 1):")
                print("- Application Name: '\(applicationName)'")
                print("- Package Status: '\(packageStatus)'")
                print("- Readiness Date: \(readinessDate.map { $0.description } ?? "nil")")
                
                if record.isValid {
                    print("Record is valid")
                    let normalizedName = record.normalizedApplicationName
                    if seenApplicationNames.contains(normalizedName) {
                        print("Found duplicate application name: '\(applicationName)' (normalized: '\(normalizedName)')")
                        duplicateRecords.append("Row \(index + 1): Duplicate Application Name '\(applicationName)'")
                        processedDuplicateRows += 1
                    } else {
                        print("New unique application name: '\(applicationName)' (normalized: '\(normalizedName)')")
                        seenApplicationNames.insert(normalizedName)
                        validRecords.append(record)
                        processedValidRows += 1
                    }
                } else {
                    print("Record is invalid: \(record.validationErrors)")
                    invalidRecords.append("Row \(index + 1): \(record.validationErrors.joined(separator: ", "))")
                    processedInvalidRows += 1
                }
                
                // Log progress for every 10000 records
                if index % 10000 == 0 {
                    print("""
                    Processing progress:
                    Row: \(index)
                    Valid: \(processedValidRows)
                    Invalid: \(processedInvalidRows)
                    Duplicates: \(processedDuplicateRows)
                    Total processed: \(processedValidRows + processedInvalidRows + processedDuplicateRows)
                    """)
                }
            }
            
            // Final progress update
            let summary = """
            Phase 5/5: Import complete
            Valid records: \(validRecords.count)
            Invalid records: \(invalidRecords.count)
            Duplicate records: \(duplicateRecords.count)
            """
            
            await MainActor.run {
                progress.update(operation: summary, progress: 1.0)
            }
            
            return (validRecords, invalidRecords, duplicateRecords)
        } catch {
            print("Error processing package status data: \(error)")
            return ([], [], [])
        }
    }
    
    private func processTestData(_ xlsx: XLSXFile) async throws -> (valid: [TestingData], invalid: [String], duplicates: [String]) {
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Initializing...", progress: 0.05)
        }
        
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        guard let path = worksheetPaths.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheets found"])
        }
        
        let worksheet = try xlsx.parseWorksheet(at: path)
        let sharedStrings = try xlsx.parseSharedStrings()
        
        // Get headers for validation
        if let firstRow = worksheet.data?.rows.first {
            let headers = firstRow.cells.map { cell -> String in
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    return sharedStrings.items[stringIndex].text ?? ""
                }
                return cell.value ?? ""
            }
            
            try validateDataType(headers, expected: .testing)
        }
        
        var validRecords: [TestingData] = []
        var invalidRecords: [String] = []
        var duplicateRecords: [String] = []
        var seenApplicationNames = Set<String>()
        
        let rows = worksheet.data?.rows ?? []
        var startDataIndex = -1
        var headerRowIndex = -1
        var columnMap: [String: Int] = [:]
        
        // Find the start marker and header row
        for (index, row) in rows.enumerated() {
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    cellValue = sharedStrings.items[stringIndex].text ?? ""
                } else {
                    cellValue = cell.value ?? ""
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                }
            }
            
            if startDataIndex == -1 {
                let rowText = fullRowContent.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                if rowText.contains("=startdatabelow=") || 
                   rowText.contains("===startdatabelow===") ||
                   rowText.contains("start data below") {
                    startDataIndex = index
                }
            } else if headerRowIndex == -1 {
                // Check for header row
                let headerVariations = ["Application Name", "Test Status", "Test Date", "Test Result", "Testing Plan Date"]
                let foundHeader = fullRowContent.contains { content in
                    let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                    return headerVariations.map { $0.lowercased() }.contains(normalizedContent)
                }
                
                if foundHeader {
                    headerRowIndex = index
                    // Map column indices to standardized header names
                    for (colIndex, content) in fullRowContent.enumerated() {
                        let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                        let standardHeader: String
                        switch normalizedContent {
                        case "application name", "applicationname", "application_name":
                            standardHeader = "Application Name"
                        case "test status", "teststatus", "test_status":
                            standardHeader = "Test Status"
                        case "test date", "testdate", "test_date":
                            standardHeader = "Test Date"
                        case "test result", "testresult", "test_result":
                            standardHeader = "Test Result"
                        case "testing plan date", "testingplandate", "testing_plan_date":
                            standardHeader = "Testing Plan Date"
                        default:
                            continue
                        }
                        columnMap[standardHeader] = colIndex
                    }
                }
            }
            
            if startDataIndex != -1 && headerRowIndex != -1 {
                break
            }
        }
        
        guard startDataIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find '===START DATA BELOW===' marker"])
        }
        
        guard headerRowIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find header row"])
        }
        
        // Process only the rows after the header
        let dataRows = rows.dropFirst(headerRowIndex + 1)
        let totalRows = dataRows.count
        
        await MainActor.run {
            progress.update(operation: "Phase 4/5: Found \(totalRows) rows to process...", progress: 0.72)
        }
        
        var processedValidRows = 0
        var processedInvalidRows = 0
        var processedDuplicateRows = 0
        
        for (index, row) in dataRows.enumerated() {
            if index % 50 == 0 {
                let progressValue = 0.72 + (0.18 * Double(index) / Double(max(1, totalRows)))
                let stats = """
                Phase 4/5: Processing rows...
                Row: \(index) of \(totalRows)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                """
                await MainActor.run {
                    progress.update(operation: stats, progress: progressValue)
                }
            }
            
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                }
            }
            
            // Skip empty rows
            if fullRowContent.allSatisfy({ $0 == "N/A" }) {
                continue
            }
            
            let applicationName = fullRowContent[safe: columnMap["Application Name"] ?? -1] ?? "N/A"
            let testStatus = fullRowContent[safe: columnMap["Test Status"] ?? -1] ?? "N/A"
            let testDateStr = fullRowContent[safe: columnMap["Test Date"] ?? -1] ?? "N/A"
            let testResult = fullRowContent[safe: columnMap["Test Result"] ?? -1] ?? "N/A"
            let testingPlanDateStr = fullRowContent[safe: columnMap["Testing Plan Date"] ?? -1]
            
            // Parse test date and testing plan date
            var testDate: Date? = nil
            var testingPlanDate: Date? = nil
            
            // Parse test date
            if testDateStr != "N/A" {
                var dateParsed = false
                
                // Try Excel serial date first
                if let serialNumber = Double(testDateStr) {
                    let excelEpoch = DateComponents(year: 1899, month: 12, day: 30)
                    if let excelBaseDate = Calendar.current.date(from: excelEpoch) {
                        testDate = Calendar.current.date(byAdding: .day, value: Int(serialNumber), to: excelBaseDate)
                        dateParsed = true
                    }
                }
                
                // Only try other formats if Excel format failed
                if !dateParsed {
                    let dateFormatters = [
                        DateFormatter.hrDateFormatter,
                        DateFormatter.hrDateParser
                    ]
                    
                    for formatter in dateFormatters {
                        if let date = formatter.date(from: testDateStr) {
                            testDate = date
                            dateParsed = true
                            break
                        }
                    }
                }
                
                if !dateParsed {
                    invalidRecords.append("Row \(index + 1): Invalid Test Date format '\(testDateStr)'")
                    processedInvalidRows += 1
                    continue
                }
            }
            
            // Parse testing plan date
            if let planDateStr = testingPlanDateStr, planDateStr != "N/A" {
                let dateFormatters = [
                    DateFormatter.hrDateFormatter,
                    DateFormatter.hrDateParser
                ]
                
                for formatter in dateFormatters {
                    if let date = formatter.date(from: planDateStr) {
                        testingPlanDate = date
                        break
                    }
                }
                
                // Try Excel serial date if other formats fail
                if testingPlanDate == nil, let serialNumber = Double(planDateStr) {
                    let excelEpoch = DateComponents(year: 1899, month: 12, day: 30)
                    if let excelBaseDate = Calendar.current.date(from: excelEpoch) {
                        testingPlanDate = Calendar.current.date(byAdding: .day, value: Int(serialNumber), to: excelBaseDate)
                    }
                }
            }
            
            // Create and validate record
            let record = TestingData(
                applicationName: applicationName,
                testStatus: testStatus,
                testDate: testDate,
                testResult: testResult,
                testingPlanDate: testingPlanDate
            )
            
            if record.isValid {
                if seenApplicationNames.contains(applicationName) {
                    duplicateRecords.append("Row \(index + 1): Duplicate Application Name '\(applicationName)'")
                    processedDuplicateRows += 1
                } else {
                    seenApplicationNames.insert(applicationName)
                    validRecords.append(record)
                    processedValidRows += 1
                }
            } else {
                invalidRecords.append("Row \(index + 1): \(record.validationErrors.joined(separator: ", "))")
                processedInvalidRows += 1
            }
        }
        
        // Final progress update
        let summary = """
        Processing complete:
        Valid records: \(processedValidRows)
        Invalid records: \(processedInvalidRows)
        Duplicate records: \(processedDuplicateRows)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 1.0)
        }
        
        return (validRecords, invalidRecords, duplicateRecords)
    }
    
    private func processMigrationData(_ xlsx: XLSXFile) async throws -> ([MigrationData], [String], [String]) {
        var validRecords: [MigrationData] = []
        var invalidRecords: [String] = []
        var duplicateRecords: [String] = []
        var seenApplicationNames = Set<String>()
        
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Reading worksheet data...", progress: 0.1)
        }
        
        // Get the first worksheet
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        guard let worksheetPath = worksheetPaths.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheet found in the file"])
        }
        
        let worksheet = try xlsx.parseWorksheet(at: worksheetPath)
        let sharedStrings = try xlsx.parseSharedStrings()
        let totalRows = worksheet.data?.rows.count ?? 0
        
        // Find the start marker and header row
        var headerRowIndex = -1
        var startDataIndex = -1
        var columnMap: [String: Int] = [:]
        
        // Process each row to find start marker and headers
        for (index, row) in (worksheet.data?.rows ?? []).enumerated() {
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            // Calculate the maximum column index needed
            let maxColumnIndex = max(
                rowContent.map { $0.index }.max() ?? 0,
                50  // Minimum size to ensure we have enough space
            )
            
            // Create array with sufficient size
            var fullRowContent: [String] = Array(repeating: "N/A", count: maxColumnIndex + 1)
            
            // Safely populate the array
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                }
            }
            
            if startDataIndex == -1 {
                let rowText = fullRowContent.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                if rowText.contains("=startdatabelow=") || 
                   rowText.contains("===startdatabelow===") ||
                   rowText.contains("start data below") {
                    startDataIndex = index
                }
            } else if headerRowIndex == -1 {
                // Check for header row
                let headerVariations = ["Application Name", "ApplicationName", "Application-Name", "Application_Name", "App Name", "ID"]
                let foundHeader = fullRowContent.contains { content in
                    let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                    return headerVariations.contains { variation in
                        normalizedContent == variation.lowercased()
                    }
                }
                
                if foundHeader {
                    headerRowIndex = index
                    // Map column headers
                    for (colIndex, header) in fullRowContent.enumerated() {
                        let normalizedHeader = header.trimmingCharacters(in: .whitespaces)
                        let standardHeader: String
                        switch normalizedHeader.lowercased() {
                        case "application name", "applicationname", "app name", "id":
                            standardHeader = "Application Name"
                        case "application new", "applicationnew":
                            standardHeader = "Application New"
                        case "application suite new", "applicationsuitenew":
                            standardHeader = "Application Suite New"
                        case "will be", "willbe":
                            standardHeader = "Will Be"
                        case "in/out scope division", "inscope/outscope", "in scope out scope division":
                            standardHeader = "In/Out Scope Division"
                        case "migration platform", "migrationplatform":
                            standardHeader = "Migration Platform"
                        case "application readiness", "applicationreadiness", "migration application readiness":
                            standardHeader = "Migration Application Readiness"
                        default:
                            continue
                        }
                        columnMap[standardHeader] = colIndex
                    }
                }
            }
            
            if startDataIndex != -1 && headerRowIndex != -1 {
                break
            }
        }
        
        guard startDataIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find '===START DATA BELOW===' marker"])
        }
        
        guard headerRowIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find header row with required columns"])
        }
        
        // Process only the rows after the header
        let dataRows = (worksheet.data?.rows ?? []).dropFirst(headerRowIndex + 1)
        let totalDataRows = dataRows.count
        
        await MainActor.run {
            progress.update(operation: "Phase 4/5: Found \(totalDataRows) rows to process...", progress: 0.72)
        }
        
        var processedValidRows = 0
        var processedInvalidRows = 0
        var processedDuplicateRows = 0
        
        for (index, row) in dataRows.enumerated() {
            if index % 50 == 0 {
                let progressValue = 0.72 + (0.18 * Double(index) / Double(max(1, totalDataRows)))
                let stats = """
                Phase 4/5: Processing rows...
                Row: \(index) of \(totalDataRows)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                """
                await MainActor.run {
                    progress.update(operation: stats, progress: progressValue)
                }
            }
            
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            // Calculate the maximum column index needed
            let maxColumnIndex = max(
                columnMap.values.max() ?? 0,
                rowContent.map { $0.index }.max() ?? 0
            )
            
            // Create array with sufficient size
            var fullRowContent: [String] = Array(repeating: "N/A", count: maxColumnIndex + 1)
            
            // Safely populate the array
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                }
            }
            
            // Skip empty rows
            if fullRowContent.allSatisfy({ $0 == "N/A" }) {
                continue
            }
            
            let applicationName = fullRowContent[safe: columnMap["Application Name"] ?? -1] ?? "N/A"
            let applicationNew = fullRowContent[safe: columnMap["Application New"] ?? -1] ?? ""
            let applicationSuiteNew = fullRowContent[safe: columnMap["Application Suite New"] ?? -1] ?? ""
            let willBe = fullRowContent[safe: columnMap["Will Be"] ?? -1] ?? ""
            let inScopeOutScopeDivision = fullRowContent[safe: columnMap["In/Out Scope Division"] ?? -1] ?? ""
            let migrationPlatform = fullRowContent[safe: columnMap["Migration Platform"] ?? -1] ?? ""
            let migrationApplicationReadiness = fullRowContent[safe: columnMap["Migration Application Readiness"] ?? -1] ?? ""
            
            let record = MigrationData(
                applicationName: applicationName,
                applicationNew: applicationNew,
                applicationSuiteNew: applicationSuiteNew,
                willBe: willBe,
                inScopeOutScopeDivision: inScopeOutScopeDivision,
                migrationPlatform: migrationPlatform,
                migrationApplicationReadiness: migrationApplicationReadiness
            )
            
            if record.isValid {
                let normalizedName = record.normalizedApplicationName
                if seenApplicationNames.contains(normalizedName) {
                    duplicateRecords.append("Row \(index + 1): Duplicate Application Name '\(applicationName)'")
                    processedDuplicateRows += 1
                } else {
                    seenApplicationNames.insert(normalizedName)
                    validRecords.append(record)
                    processedValidRows += 1
                }
            } else {
                invalidRecords.append("Row \(index + 1): \(record.validationErrors.joined(separator: ", "))")
                processedInvalidRows += 1
            }
            
            // Log progress for every 10000 records
            if index % 10000 == 0 {
                print("""
                Processing progress:
                Row: \(index)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                Total processed: \(processedValidRows + processedInvalidRows + processedDuplicateRows)
                """)
            }
        }
        
        // Final progress update
        let summary = """
        Processing complete:
        Valid records: \(processedValidRows)
        Invalid records: \(processedInvalidRows)
        Duplicate records: \(processedDuplicateRows)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 1.0)
        }
        
        return (validRecords, invalidRecords, duplicateRecords)
    }
    
    private func processClusterData(_ xlsx: XLSXFile) async throws -> (valid: [ClusterData], invalid: [String], duplicates: [String]) {
        // Initial setup and Excel reading phase (0-40%)
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Initializing...", progress: 0.05)
        }
        
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        guard let path = worksheetPaths.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheets found"])
        }
        
        let worksheet = try xlsx.parseWorksheet(at: path)
        let sharedStrings = try xlsx.parseSharedStrings()
        
        // Get headers for validation
        if let firstRow = worksheet.data?.rows.first {
            let headers = firstRow.cells.map { cell -> String in
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    return sharedStrings.items[stringIndex].text ?? ""
                }
                return cell.value ?? ""
            }
            
            // Validate data type
            try validateDataType(headers, expected: .cluster)
        }
        
        // Worksheet loading phase (40-60%)
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Loading worksheet data...", progress: 0.40)
        }
        
        let rows = worksheet.data?.rows ?? []
        var startDataIndex = -1
        var headerRowIndex = -1
        var columnMap: [String: Int] = [:]
        
        // Find the start marker and header row
        for (index, row) in rows.enumerated() {
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    cellValue = sharedStrings.items[stringIndex].text ?? ""
                } else {
                    cellValue = cell.value ?? ""
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                }
            }
            
            if startDataIndex == -1 {
                let rowText = fullRowContent.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                    .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                if rowText.contains("=startdatabelow=") || 
                   rowText.contains("===startdatabelow===") ||
                   rowText.contains("start data below") {
                    startDataIndex = index
                }
            } else if headerRowIndex == -1 {
                // Check for header row
                let headerVariations = ["Department", "Department Simple", "Domain", "Migration Cluster"]
                let foundHeader = fullRowContent.contains { content in
                    let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                    return headerVariations.map { $0.lowercased() }.contains(normalizedContent)
                }
                
                if foundHeader {
                    headerRowIndex = index
                    // Map column indices to standardized header names
                    for (colIndex, content) in fullRowContent.enumerated() {
                        let normalizedContent = content.lowercased().trimmingCharacters(in: .whitespaces)
                        let standardHeader: String
                        switch normalizedContent {
                        case "department":
                            standardHeader = "Department"
                        case "department simple", "departmentsimple", "department_simple":
                            standardHeader = "Department Simple"
                        case "domain":
                            standardHeader = "Domain"
                        case "migration cluster", "migrationcluster", "migration_cluster":
                            standardHeader = "Migration Cluster"
                        default:
                            continue
                        }
                        columnMap[standardHeader] = colIndex
                    }
                }
            }
            
            if startDataIndex != -1 && headerRowIndex != -1 {
                break
            }
        }
        
        guard startDataIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find '===START DATA BELOW===' marker"])
        }
        
        guard headerRowIndex != -1 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find header row"])
        }
        
        // Process only the rows after the header
        let dataRows = rows.dropFirst(headerRowIndex + 1)
        let totalRows = dataRows.count
        
        await MainActor.run {
            progress.update(operation: "Phase 4/5: Found \(totalRows) rows to process...", progress: 0.72)
        }
        
        var validRecords: [ClusterData] = []
        var invalidRecords: [String] = []
        let duplicateRecords: [String] = []
        
        var processedValidRows = 0
        var processedInvalidRows = 0
        let processedDuplicateRows = 0
        
        for (index, row) in dataRows.enumerated() {
            if index % 50 == 0 {
                let progressValue = 0.72 + (0.18 * Double(index) / Double(max(1, totalRows)))
                let stats = """
                Phase 4/5: Processing rows...
                Row: \(index) of \(totalRows)
                Valid: \(processedValidRows)
                Invalid: \(processedInvalidRows)
                Duplicates: \(processedDuplicateRows)
                """
                await MainActor.run {
                    progress.update(operation: stats, progress: progressValue)
                }
            }
            
            let rowContent = row.cells.map { cell -> (index: Int, value: String) in
                let cellValue: String
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (index: columnIndex, value: cellValue)
            }
            
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20)
            for cell in rowContent {
                if cell.index < fullRowContent.count {
                    fullRowContent[cell.index] = cell.value
                }
            }
            
            let department = columnMap["Department"].map { fullRowContent[$0] } ?? ""
            let departmentSimple = columnMap["Department Simple"].map { fullRowContent[$0] } ?? ""
            let domain = columnMap["Domain"].map { fullRowContent[$0] } ?? ""
            let migrationCluster = columnMap["Migration Cluster"].map { fullRowContent[$0] } ?? ""
            let migrationClusterReadiness = columnMap["Migration Cluster Readiness"].map { fullRowContent[$0] } ?? ""
            
            // Skip empty rows
            if department.isEmpty || department == "N/A" {
                continue
            }
            
            // Create and validate the record
            let record = ClusterData(
                department: department,
                departmentSimple: departmentSimple,
                domain: domain,
                migrationCluster: migrationCluster,
                migrationClusterReadiness: migrationClusterReadiness
            )
            
            if record.isValid {
                // Only validate that the department exists in HR records
                let normalizedDepartment = department.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedDepartment.isEmpty {
                    validRecords.append(record)
                    processedValidRows += 1
                }
            } else {
                invalidRecords.append("Row \(index + 1): \(record.validationErrors.joined(separator: ", "))")
                processedInvalidRows += 1
            }
        }
        
        // Final progress update
        let summary = """
        Processing complete:
        Valid records: \(processedValidRows)
        Invalid records: \(processedInvalidRows)
        Duplicate records: \(processedDuplicateRows)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 1.0)
        }
        
        return (validRecords, invalidRecords, duplicateRecords)
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Helper function to convert Excel column letters to index
extension String {
    func excelColumnToIndex() -> Int {
        return self.uppercased().unicodeScalars.reduce(0) { total, char in
            return total * 26 + Int(char.value - 65 + 1)
        } - 1  // Convert to 0-based index
    }
}

#Preview {
    ImportView()
} 