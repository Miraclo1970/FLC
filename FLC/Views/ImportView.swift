import SwiftUI
import UniformTypeIdentifiers
import CoreXLSX

@available(macOS 14.0, *)
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
        } else if firstRow.contains("package") || firstRow.contains("status") {
            return .packageStatus
        } else if firstRow.contains("test") || firstRow.contains("status") {
            return .testing
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
        }
        
        // First try to find the template in the bundle
        if let templateURL = Bundle.main.url(forResource: fileName, withExtension: "xlsx") {
            NSWorkspace.shared.open(templateURL)
        } else {
            // If not in bundle, try to find it relative to the executable path
            let executableURL = Bundle.main.bundleURL
            let templateURL = executableURL.deletingLastPathComponent().appendingPathComponent("\(fileName).xlsx")
            
            if FileManager.default.fileExists(atPath: templateURL.path) {
                NSWorkspace.shared.open(templateURL)
            } else {
                print("Template file not found: \(fileName).xlsx")
                print("Tried bundle path and: \(templateURL.path)")
                message = "Error: Template file not found"
            }
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
                    let (valid, _, _) = try await processPackageStatusData(xlsx)
                    await MainActor.run {
                        print("Setting Package Status records - Valid: \(valid.count)")
                        progress.selectedDataType = .packageStatus
                        progress.validPackageRecords = valid
                        message = "Successfully processed Package Status data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed Package Status records - Valid: \(valid.count)")
                        print("Data type is now: \(progress.selectedDataType)")
                        // Dismiss this view to return to the main navigation
                        dismiss()
                    }
                    
                case .testing:
                    let (valid, _, _) = try await processTestStatusData(xlsx)
                    await MainActor.run {
                        print("Setting Test Status records - Valid: \(valid.count)")
                        progress.selectedDataType = .testing
                        progress.validTestRecords = valid
                        message = "Successfully processed Test Status data from: \(file.lastPathComponent)"
                        progress.isProcessing = false
                        print("Processed Test Status records - Valid: \(valid.count)")
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
            
            // Convert to array with proper handling of missing cells
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20) // Ensure array is big enough
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
            
            // Convert to array with proper handling of missing cells
            var fullRowContent: [String] = Array(repeating: "N/A", count: 20) // Ensure array is big enough
            for cell in rowContent {
                fullRowContent[cell.index] = cell.value
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
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                let columnIndex: Int
                let columnString = cell.reference.column.value
                columnIndex = columnString.excelColumnToIndex()
                
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
                        case "employee nr", "employeenr", "employee-nr", "employee_nr":
                            standardHeader = "Employee Number"
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
                    let text = sharedStrings.items[stringIndex].text ?? ""
                    cellValue = text.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : text
                } else {
                    let value = cell.value ?? ""
                    cellValue = value.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : value
                }
                
                let columnIndex: Int
                let columnString = cell.reference.column.value
                columnIndex = columnString.excelColumnToIndex()
                
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
            let department = fullRowContent[safe: columnMap["Department"] ?? -1] ?? "N/A"
            let jobRole = fullRowContent[safe: columnMap["Job Role"] ?? -1] ?? "N/A"
            let division = fullRowContent[safe: columnMap["Division"] ?? -1] ?? "N/A"
            let leaveDateStr = fullRowContent[safe: columnMap["Leave Date"] ?? -1] ?? "N/A"
            let employeeNumber = fullRowContent[safe: columnMap["Employee Number"] ?? -1] ?? "N/A"
            
            if index == 0 || index % 10000 == 0 {
                print("Column Map: \(columnMap)")
                print("Row \(index) values - System Account: \(systemAccount), Employee Number: \(employeeNumber)")
                print("Leave Date Column Index: \(columnMap["Leave Date"] ?? -1)")
                print("Leave Date Raw Value: \(leaveDateStr)")
            }
            
            // Parse leave date if present
            var leaveDate: Date? = nil
            if leaveDateStr != "N/A" {
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
                department: department != "N/A" ? department : nil,
                jobRole: jobRole != "N/A" ? jobRole : nil,
                division: division != "N/A" ? division : nil,
                leaveDate: leaveDate,
                employeeNumber: employeeNumber != "N/A" ? employeeNumber : nil
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
        let invalidRecords: [String] = []
        let duplicateRecords: [String] = []
        
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
        
        // Validate header row
        guard let firstRow = worksheet.data?.rows.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data found in worksheet"])
        }
        
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
        
        // Check for Package Status header
        let headerText = headers.joined(separator: " ").lowercased()
        guard headerText.contains("package") && headerText.contains("status") else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file format: Expected Package Status data but found different content"])
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Processing \(totalRows) rows...", progress: 0.2)
        }
        
        // Process each row
        var processedValidRows = 0
        
        // Skip first two rows (header and column names)
        let dataRows = (worksheet.data?.rows ?? []).dropFirst(2)
        
        for (index, row) in dataRows.enumerated() {
            let progressValue = 0.2 + (0.6 * Double(index) / Double(totalRows))
            
            // Update progress periodically
            if index % 100 == 0 {
                let stats = """
                Row: \(index) of \(totalRows)
                Valid: \(processedValidRows)
                """
                await MainActor.run {
                    progress.update(operation: stats, progress: progressValue)
                }
            }
            
            let rowContent = row.cells.map { cell -> (columnIndex: Int, value: String) in
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
                return (columnIndex: columnIndex, value: cellValue)
            }
            
            // Create a dictionary for easier column access
            var rowData: [Int: String] = [:]
            for content in rowContent {
                rowData[content.columnIndex] = content.value
            }
            
            // Extract data from the correct columns
            let applicationName = rowData[0] ?? "N/A"
            let packageStatus = rowData[1] ?? "N/A"
            let packageReadinessDateStr = rowData[2] ?? ""
            
            // Parse the package readiness date
            var packageReadinessDate: Date? = nil
            if !packageReadinessDateStr.isEmpty && packageReadinessDateStr != "N/A" {
                // Try different date formats
                let dateFormatters = [
                    "dd-MM-yyyy",
                    "yyyy-MM-dd",
                    "MM/dd/yyyy",
                    "dd/MM/yyyy"
                ].map { format -> DateFormatter in
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    return formatter
                }
                
                for formatter in dateFormatters {
                    if let date = formatter.date(from: packageReadinessDateStr) {
                        packageReadinessDate = date
                        break
                    }
                }
            }
            
            // Validate the record
            if applicationName != "N/A" && packageStatus != "N/A" {
                let record = PackageStatusData(
                    id: nil,
                    systemAccount: "", // Not used for package status
                    applicationName: applicationName,
                    packageStatus: packageStatus,
                    packageReadinessDate: packageReadinessDate,
                    importDate: Date(),
                    importSet: UUID().uuidString
                )
                validRecords.append(record)
                processedValidRows += 1
            }
        }
        
        // Final progress update
        let summary = """
        Processing complete:
        Valid records: \(processedValidRows)
        Invalid records: \(invalidRecords.count)
        Duplicate records: \(duplicateRecords.count)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 0.95)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 5/5: Import complete!", progress: 1.0)
        }
        
        return (validRecords, invalidRecords, duplicateRecords)
    }
    
    private func processTestStatusData(_ xlsx: XLSXFile) async throws -> ([TestingData], [String], [String]) {
        var validRecords: [TestingData] = []
        let invalidRecords: [String] = []
        let duplicateRecords: [String] = []
        
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
        
        // Validate header row
        guard let firstRow = worksheet.data?.rows.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data found in worksheet"])
        }
        
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
        
        // Check for Test Status header
        let headerText = headers.joined(separator: " ").lowercased()
        guard headerText.contains("test") && headerText.contains("status") else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file format: Expected Test Status data but found different content"])
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Processing \(totalRows) rows...", progress: 0.2)
        }
        
        // Process each row
        var processedValidRows = 0
        
        // Skip first two rows (header and column names)
        let dataRows = (worksheet.data?.rows ?? []).dropFirst(2)
        
        for (index, row) in dataRows.enumerated() {
            let rowContent = row.cells.map { cell -> (columnIndex: Int, value: String) in
                var cellValue = ""
                
                if let sharedStrings = sharedStrings,
                   case .sharedString = cell.type,
                   let value = cell.value,
                   let stringIndex = Int(value),
                   stringIndex < sharedStrings.items.count {
                    cellValue = sharedStrings.items[stringIndex].text ?? ""
                } else if let value = cell.value {
                    cellValue = value
                }
                
                let columnIndex = cell.reference.column.value.excelColumnToIndex()
                return (columnIndex: columnIndex, value: cellValue.trimmingCharacters(in: .whitespaces))
            }
            
            // Create a dictionary for easier column access
            var rowData: [Int: String] = [:]
            for content in rowContent {
                rowData[content.columnIndex] = content.value
            }
            
            // Extract data from the correct columns (adjusted column indices)
            let applicationName = rowData[0] ?? "N/A"
            let testStatus = rowData[1] ?? "N/A"
            let testDateStr = rowData[2] ?? ""
            let testResult = rowData[3] ?? "N/A"
            let testComments = rowData[4]
            
            // Parse the test date
            var testDate: Date = Date()
            if !testDateStr.isEmpty && testDateStr != "N/A" {
                let dateFormatters = [
                    "dd-MM-yyyy",
                    "yyyy-MM-dd",
                    "MM/dd/yyyy",
                    "dd/MM/yyyy"
                ].map { format -> DateFormatter in
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    return formatter
                }
                
                for formatter in dateFormatters {
                    if let date = formatter.date(from: testDateStr) {
                        testDate = date
                        break
                    }
                }
            }
            
            // Validate the record
            if applicationName != "N/A" && testStatus != "N/A" {
                let record = TestingData(
                    applicationName: applicationName,
                    testStatus: testStatus,
                    testDate: testDate,
                    testResult: testResult,
                    testComments: testComments
                )
                validRecords.append(record)
                processedValidRows += 1
            }
            
            // Update progress
            if index % 100 == 0 {
                await MainActor.run {
                    let progress = Double(index) / Double(totalRows)
                    self.progress.update(operation: "Phase 2/5: Processing row \(index) of \(totalRows)...", progress: 0.2 + (progress * 0.6))
                }
            }
        }
        
        // Final progress update
        let summary = """
        Processing complete:
        Valid records: \(processedValidRows)
        Invalid records: \(invalidRecords.count)
        Duplicate records: \(duplicateRecords.count)
        """
        
        await MainActor.run {
            progress.update(operation: summary, progress: 0.95)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 5/5: Import complete!", progress: 1.0)
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

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportView()
    }
} 