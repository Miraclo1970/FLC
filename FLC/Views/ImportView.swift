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
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .padding()
            
            if progress.isProcessing {
                VStack(spacing: 16) {
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
            } else {
                HStack(spacing: 20) {
                    Button("Import HR Data") {
                        importType = .hr
                        showFileImporter = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import AD Data") {
                        importType = .ad
                        showFileImporter = true
                    }
                    .buttonStyle(.bordered)
                }
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
                    
                case .none:
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No import type selected"])
                }
                
            case .failure(let error):
                throw error
            }
        } catch {
            await MainActor.run {
                message = "Error: \(error.localizedDescription)"
                progress.isProcessing = false
            }
        }
    }
    
    private func processADData(_ xlsx: XLSXFile) async throws -> (valid: [ADData], invalid: [String], duplicates: [String]) {
        // Initial setup and Excel reading phase (0-40%)
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Initializing...", progress: 0.05)
        }
        
        // Get worksheets
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Opening Excel file...", progress: 0.10)
        }
        
        await MainActor.run {
            progress.update(operation: "Phase 1/5: Reading Excel structure...", progress: 0.20)
        }
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        guard let path = worksheetPaths.first else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No worksheets found"])
        }
        
        // Worksheet loading phase (40-60%)
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Loading worksheet data...", progress: 0.40)
        }
        
        // Parse worksheet
        let worksheet = try xlsx.parseWorksheet(at: path)
        await MainActor.run {
            progress.update(operation: "Phase 2/5: Loading shared strings...", progress: 0.50)
        }
        let sharedStrings = try xlsx.parseSharedStrings()
        
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
        var processedDuplicateRows = 0
        
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
                            standardHeader = "Leave Date"
                        case "employee number", "employeenumber", "employee-number", "employee_number", "empno":
                            standardHeader = "Employee Number"
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
        var processedDuplicateRows = 0
        
        let dateFormatter = DateFormatter.hrDateFormatter
        
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
            }
            
            // Parse leave date if present
            var leaveDate: Date? = nil
            if leaveDateStr != "N/A" {
                leaveDate = dateFormatter.date(from: leaveDateStr)
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