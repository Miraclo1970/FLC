import SwiftUI
import UniformTypeIdentifiers

struct ValidHRRecordsView: View {
    let records: [HRData]
    let searchText: String
    
    var filteredRecords: [HRData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.systemAccount.localizedCaseInsensitiveContains(searchText) ||
            (record.department ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.departmentSimple ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.jobRole ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.division ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#")
                            .frame(width: 50, alignment: .leading)
                            .padding(.leading, 25)
                        Text("System Account")
                            .frame(width: 200, alignment: .leading)
                        Text("Department")
                            .frame(width: 200, alignment: .leading)
                        Text("Department Simple")
                            .frame(width: 150, alignment: .leading)
                        Text("Job Role")
                            .frame(width: 200, alignment: .leading)
                        Text("Division")
                            .frame(width: 200, alignment: .leading)
                        Text("Leave Date")
                            .frame(width: 120, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.separatorColor).opacity(0.2))
                    .font(.headline)
                    
                    // Records
                    List {
                        ForEach(Array(filteredRecords.enumerated()), id: \.1.systemAccount) { index, record in
                            HStack(spacing: 0) {
                                Text("#\(index + 1)")
                                    .frame(width: 50, alignment: .leading)
                                    .padding(.leading, 10)
                                    .foregroundColor(.secondary)
                                Text(record.systemAccount)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.department ?? "N/A")
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.departmentSimple ?? "N/A")
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.jobRole ?? "N/A")
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.division ?? "N/A")
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.leaveDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
                                    .frame(width: 120, alignment: .leading)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
        }
    }
}

struct ValidationView: View {
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSaving = false
    @State private var saveResult: String?
    @ObservedObject var progress: ImportProgress
    @State private var saveProgress: Double = 0.0
    private let batchSize = 5000
    
    private var stats: [(String, String)] {
        var total = 0
        var valid = 0
        var invalid = 0
        var duplicates = 0
        
        switch progress.selectedDataType {
        case .ad:
            total = progress.validRecords.count +
                    progress.invalidRecords.count +
                    progress.duplicateRecords.count
            valid = progress.validRecords.count
            invalid = progress.invalidRecords.count
            duplicates = progress.duplicateRecords.count
        case .hr:
            total = progress.validHRRecords.count +
                    progress.invalidHRRecords.count +
                    progress.duplicateHRRecords.count
            valid = progress.validHRRecords.count
            invalid = progress.invalidHRRecords.count
            duplicates = progress.duplicateHRRecords.count
        case .packageStatus:
            total = progress.validPackageRecords.count +
                    progress.invalidPackageRecords.count +
                    progress.duplicatePackageRecords.count
            valid = progress.validPackageRecords.count
            invalid = progress.invalidPackageRecords.count
            duplicates = progress.duplicatePackageRecords.count
        case .testing:
            total = progress.validTestRecords.count +
                    progress.invalidTestRecords.count +
                    progress.duplicateTestRecords.count
            valid = progress.validTestRecords.count
            invalid = progress.invalidTestRecords.count
            duplicates = progress.duplicateTestRecords.count
        case .migration:
            total = progress.validMigrationRecords.count +
                    progress.invalidMigrationRecords.count +
                    progress.duplicateMigrationRecords.count
            valid = progress.validMigrationRecords.count
            invalid = progress.invalidMigrationRecords.count
            duplicates = progress.duplicateMigrationRecords.count
        case .cluster:
            total = progress.validClusterRecords.count +
                    progress.invalidClusterRecords.count +
                    progress.duplicateClusterRecords.count
            valid = progress.validClusterRecords.count
            invalid = progress.invalidClusterRecords.count
            duplicates = progress.duplicateClusterRecords.count
        case .combined:
            total = 0  // Combined view doesn't have its own records
        }
        
        print("ValidationView - Current data type: \(progress.selectedDataType), Valid records: \(valid)")
        return [
            ("Total Records", "\(total)"),
            ("Valid Records", "\(valid)"),
            ("Invalid Records", "\(invalid)"),
            ("Duplicate Records", "\(duplicates)")
        ]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Data Type Picker with enhanced visibility
            VStack(spacing: 8) {
                Text("Select Data Type")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Data Type", selection: $progress.selectedDataType) {
                    Text("AD Data").tag(ImportProgress.DataType.ad)
                    Text("HR Data").tag(ImportProgress.DataType.hr)
                    Text("Package Status").tag(ImportProgress.DataType.packageStatus)
                    Text("Testing").tag(ImportProgress.DataType.testing)
                    Text("Migration").tag(ImportProgress.DataType.migration)
                    Text("Cluster").tag(ImportProgress.DataType.cluster)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .onChange(of: progress.selectedDataType) { oldValue, newValue in
                    if newValue == .combined {
                        // If somehow combined is selected, switch back to AD
                        progress.selectedDataType = .ad
                    }
                    print("ValidationView - Data type changed from \(oldValue) to \(newValue)")
                    print("ValidationView - Current record counts:")
                    print("- Valid Package Records: \(progress.validPackageRecords.count)")
                    print("- Invalid Package Records: \(progress.invalidPackageRecords.count)")
                    print("- Duplicate Package Records: \(progress.duplicatePackageRecords.count)")
                    print("- Valid Migration Records: \(progress.validMigrationRecords.count)")
                    print("- Invalid Migration Records: \(progress.invalidMigrationRecords.count)")
                    print("- Duplicate Migration Records: \(progress.duplicateMigrationRecords.count)")
                }
            }
            .padding(.horizontal)
            
            // Stats Cards and Save Button
            HStack {
                // Stats Cards
                HStack(spacing: 20) {
                    ForEach(stats, id: \.0) { stat in
                        DashboardCard(
                            title: stat.0,
                            value: stat.1,
                            icon: iconForStat(stat.0)
                        )
                    }
                }
                
                Spacer()
                
                // Save Button and Download Button
                VStack(spacing: 10) {
                    if hasValidRecords {
                        VStack(spacing: 5) {
                            Button(action: saveToDatabase) {
                                if isSaving {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.7)
                                } else {
                                    Text("Save Valid Records to Database")
                                }
                            }
                            .disabled(isSaving)
                            .buttonStyle(.borderedProminent)
                            
                            if isSaving {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Saving...")
                                        .foregroundColor(.secondary)
                                    ProgressView()
                                }
                            }
                        }
                    }
                    
                    if hasInvalidOrDuplicateRecords {
                        Button(action: downloadInvalidAndDuplicates) {
                            Text("Download Invalid and Duplicates")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            
            // Save Result Message
            if let result = saveResult {
                Text(result)
                    .foregroundColor(result.contains("Error") ? .red : .green)
                    .padding(.horizontal)
            }
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search in validation results...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            // Tabs and Content
            TabView(selection: $selectedTab) {
                // Valid Records Tab
                Group {
                    switch progress.selectedDataType {
                    case .ad:
                        ValidRecordsView(records: progress.validRecords, searchText: searchText)
                    case .hr:
                        ValidHRRecordsView(records: progress.validHRRecords, searchText: searchText)
                    case .packageStatus:
                        ValidPackageStatusRecordsView(records: progress.validPackageRecords, searchText: searchText)
                    case .testing:
                        ValidTestRecordsView(records: progress.validTestRecords, searchText: searchText)
                    case .migration:
                        ValidMigrationRecordsView(records: progress.validMigrationRecords, searchText: searchText)
                    case .cluster:
                        ValidClusterRecordsView(records: progress.validClusterRecords, searchText: searchText)
                    case .combined:
                        Text("Combined records cannot be validated")
                    }
                }
                .tabItem {
                    Label("Valid", systemImage: "checkmark.circle")
                }
                .tag(0)
                
                // Invalid Records Tab
                Group {
                    switch progress.selectedDataType {
                    case .ad:
                        InvalidRecordsView(records: progress.invalidRecords, searchText: searchText)
                    case .hr:
                        InvalidRecordsView(records: progress.invalidHRRecords, searchText: searchText)
                    case .packageStatus:
                        InvalidRecordsView(records: progress.invalidPackageRecords, searchText: searchText)
                    case .testing:
                        InvalidRecordsView(records: progress.invalidTestRecords, searchText: searchText)
                    case .migration:
                        InvalidRecordsView(records: progress.invalidMigrationRecords, searchText: searchText)
                    case .cluster:
                        InvalidRecordsView(records: progress.invalidClusterRecords, searchText: searchText)
                    default:
                        Text("No invalid records to display")
                    }
                }
                .tabItem {
                    Label("Invalid", systemImage: "xmark.circle")
                }
                .tag(1)
                
                // Duplicate Records Tab
                Group {
                    switch progress.selectedDataType {
                    case .ad:
                        DuplicateRecordsView(records: progress.duplicateRecords, searchText: searchText)
                    case .hr:
                        DuplicateRecordsView(records: progress.duplicateHRRecords, searchText: searchText)
                    case .packageStatus:
                        DuplicateRecordsView(records: progress.duplicatePackageRecords, searchText: searchText)
                    case .testing:
                        DuplicateRecordsView(records: progress.duplicateTestRecords, searchText: searchText)
                    case .migration:
                        DuplicateRecordsView(records: progress.duplicateMigrationRecords, searchText: searchText)
                    case .cluster:
                        DuplicateRecordsView(records: progress.duplicateClusterRecords, searchText: searchText)
                    default:
                        Text("No duplicate records to display")
                    }
                }
                .tabItem {
                    Label("Duplicates", systemImage: "doc.on.doc")
                }
                .tag(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        // Reset to valid records tab when switching data types
        .onChange(of: progress.selectedDataType) { oldValue, newValue in
            selectedTab = 0
        }
    }
    
    private func iconForStat(_ stat: String) -> String {
        switch stat {
        case "Total Records":
            return "doc.text"
        case "Valid Records":
            return "checkmark.circle"
        case "Invalid Records":
            return "xmark.circle"
        case "Duplicate Records":
            return "doc.on.doc"
        default:
            return "doc"
        }
    }
}

struct ValidRecordsView: View {
    let records: [ADData]
    let searchText: String
    
    var filteredRecords: [ADData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.adGroup.localizedCaseInsensitiveContains(searchText) ||
            record.systemAccount.localizedCaseInsensitiveContains(searchText) ||
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.applicationSuite.localizedCaseInsensitiveContains(searchText) ||
            record.otap.localizedCaseInsensitiveContains(searchText) ||
            record.critical.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#")
                            .frame(width: 50, alignment: .leading)
                            .padding(.leading, 25)
                        Text("AD Group")
                            .frame(width: 300, alignment: .leading)
                        Text("System Account")
                            .frame(width: 200, alignment: .leading)
                        Text("Application")
                            .frame(width: 250, alignment: .leading)
                        Text("Suite")
                            .frame(width: 200, alignment: .leading)
                        Text("OTAP")
                            .frame(width: 80, alignment: .leading)
                        Text("Critical")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.separatorColor).opacity(0.2))
                    .font(.headline)
                    
                    // Records
                    List {
                        ForEach(Array(filteredRecords.enumerated()), id: \.element.id) { index, record in
                            if index > 0 {  // Skip the first row (header)
                                HStack(spacing: 0) {
                                    Text("#\(index)")
                                        .frame(width: 50, alignment: .leading)
                                        .padding(.leading, 10)
                                        .foregroundColor(.secondary)
                                    Text(record.adGroup)
                                        .frame(width: 300, alignment: .leading)
                                        .lineLimit(1)
                                    Text(record.systemAccount)
                                        .frame(width: 200, alignment: .leading)
                                        .lineLimit(1)
                                    Text(record.applicationName)
                                        .frame(width: 250, alignment: .leading)
                                        .lineLimit(1)
                                    Text(record.applicationSuite)
                                        .frame(width: 200, alignment: .leading)
                                        .lineLimit(1)
                                    Text(record.otap)
                                        .frame(width: 80, alignment: .leading)
                                        .lineLimit(1)
                                    Text(record.critical)
                                        .frame(width: 80, alignment: .leading)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct InvalidRecordsView: View {
    let records: [String]
    let searchText: String
    
    var filteredRecords: [String] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 40, alignment: .leading)
                Text("Error Message")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(NSColor.separatorColor).opacity(0.2))
            .font(.headline)
            
            if records.isEmpty {
                Text("No invalid records found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Records
                List {
                    ForEach(Array(filteredRecords.enumerated()), id: \.element) { index, record in
                        HStack(spacing: 0) {
                            Text("#\(index + 1)")
                                .frame(width: 40, alignment: .leading)
                                .foregroundColor(.secondary)
                            Text(record)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.red)
                                .lineLimit(nil) // Allow multiple lines
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }
}

struct DuplicateRecordsView: View {
    let records: [String]
    let searchText: String
    
    var filteredRecords: [String] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 40, alignment: .leading)
                Text("Duplicate Information")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(NSColor.separatorColor).opacity(0.2))
            .font(.headline)
            
            // Records
            List {
                ForEach(Array(filteredRecords.enumerated()), id: \.element) { index, record in
                    HStack(spacing: 0) {
                        Text("#\(index + 1)")
                            .frame(width: 40, alignment: .leading)
                            .foregroundColor(.secondary)
                        Text(record)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .font(.system(.body, design: .monospaced))
                }
            }
        }
    }
}

extension ValidationView {
    private var hasValidRecords: Bool {
        switch progress.selectedDataType {
        case .ad:
            return !progress.validRecords.isEmpty
        case .hr:
            return !progress.validHRRecords.isEmpty
        case .packageStatus:
            return !progress.validPackageRecords.isEmpty
        case .testing:
            return !progress.validTestRecords.isEmpty
        case .migration:
            return !progress.validMigrationRecords.isEmpty
        case .cluster:
            return !progress.validClusterRecords.isEmpty
        case .combined:
            return false  // Combined view doesn't have its own records
        }
    }
    
    private var hasInvalidOrDuplicateRecords: Bool {
        switch progress.selectedDataType {
        case .ad:
            return !progress.invalidRecords.isEmpty ||
                   !progress.duplicateRecords.isEmpty
        case .hr:
            return !progress.invalidHRRecords.isEmpty ||
                   !progress.duplicateHRRecords.isEmpty
        case .packageStatus:
            return !progress.invalidPackageRecords.isEmpty ||
                   !progress.duplicatePackageRecords.isEmpty
        case .testing:
            return !progress.invalidTestRecords.isEmpty ||
                   !progress.duplicateTestRecords.isEmpty
        case .migration:
            return !progress.invalidMigrationRecords.isEmpty ||
                   !progress.duplicateMigrationRecords.isEmpty
        case .cluster:
            return !progress.invalidClusterRecords.isEmpty ||
                   !progress.duplicateClusterRecords.isEmpty
        case .combined:
            return false  // Combined view doesn't have its own records
        }
    }
    
    private func downloadInvalidAndDuplicates() {
        Task { @MainActor in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.commaSeparatedText]
            savePanel.nameFieldStringValue = "invalid_and_duplicates.csv"
            savePanel.canCreateDirectories = true
            
            let response = await savePanel.begin()
            
            if response == .OK, let url = savePanel.url {
                var csvContent = "Type,Record\n"  // Simplified header
                
                // Add invalid records
                let invalidRecords = progress.selectedDataType == .ad ? progress.invalidRecords : progress.invalidHRRecords
                for record in invalidRecords {
                    let escapedRecord = record.replacingOccurrences(of: "\"", with: "\"\"")
                    csvContent += "Invalid,\"\(escapedRecord)\"\n"
                }
                
                // Add duplicate records
                let duplicateRecords = progress.selectedDataType == .ad ? progress.duplicateRecords : progress.duplicateHRRecords
                for record in duplicateRecords {
                    let escapedRecord = record.replacingOccurrences(of: "\"", with: "\"\"")
                    csvContent += "Duplicate,\"\(escapedRecord)\"\n"
                }
                
                do {
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    saveResult = "Successfully downloaded invalid and duplicate records to CSV file."
                } catch {
                    saveResult = "Error saving CSV file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveToDatabase() {
        isSaving = true
        saveProgress = 0.0
        saveResult = nil
        
        Task {
            do {
                switch progress.selectedDataType {
                case .ad:
                    let records = progress.validRecords
                    var totalSaved = 0
                    var totalSkipped = 0
                    let totalBatches = Int(ceil(Double(records.count) / Double(batchSize)))
                    
                    for batchIndex in 0..<totalBatches {
                        let start = batchIndex * batchSize
                        let end = min(start + batchSize, records.count)
                        let batch = Array(records[start..<end])
                        
                        let (saved, skipped) = try await DatabaseManager.shared.saveADRecords(batch)
                        totalSaved += saved
                        totalSkipped += skipped
                        
                        await MainActor.run {
                            saveProgress = Double(end) / Double(records.count)
                            saveResult = "Processing: \(end)/\(records.count) records..."
                        }
                    }
                    
                    await MainActor.run {
                        saveProgress = 1.0
                        saveResult = "Successfully saved \(totalSaved) records to database. \(totalSkipped) records skipped (duplicates)."
                    }
                    
                case .hr:
                    let records = progress.validHRRecords
                    var totalSaved = 0
                    var totalSkipped = 0
                    let totalBatches = Int(ceil(Double(records.count) / Double(batchSize)))
                    
                    for batchIndex in 0..<totalBatches {
                        let start = batchIndex * batchSize
                        let end = min(start + batchSize, records.count)
                        let batch = Array(records[start..<end])
                        
                        let (saved, skipped) = try await DatabaseManager.shared.saveHRRecords(batch)
                        totalSaved += saved
                        totalSkipped += skipped
                        
                        await MainActor.run {
                            saveProgress = Double(end) / Double(records.count)
                            saveResult = "Processing: \(end)/\(records.count) records..."
                        }
                    }
                    
                    await MainActor.run {
                        saveProgress = 1.0
                        saveResult = "Successfully saved \(totalSaved) records to database. \(totalSkipped) records skipped (duplicates)."
                    }
                case .packageStatus:
                    let records = progress.validPackageRecords
                    var totalSaved = 0
                    var totalSkipped = 0
                    let totalBatches = Int(ceil(Double(records.count) / Double(batchSize)))
                    
                    for batchIndex in 0..<totalBatches {
                        let start = batchIndex * batchSize
                        let end = min(start + batchSize, records.count)
                        let batch = Array(records[start..<end])
                        
                        let (saved, skipped) = try await DatabaseManager.shared.savePackageRecords(batch)
                        totalSaved += saved
                        totalSkipped += skipped
                        
                        await MainActor.run {
                            saveProgress = Double(end) / Double(records.count)
                            saveResult = "Processing: \(end)/\(records.count) records..."
                        }
                    }
                    
                    await MainActor.run {
                        saveProgress = 1.0
                        saveResult = "Successfully saved \(totalSaved) records to database. \(totalSkipped) records skipped (duplicates)."
                    }
                case .testing:
                    let records = progress.validTestRecords
                    var totalSaved = 0
                    var totalSkipped = 0
                    let totalBatches = Int(ceil(Double(records.count) / Double(batchSize)))
                    
                    for batchIndex in 0..<totalBatches {
                        let start = batchIndex * batchSize
                        let end = min(start + batchSize, records.count)
                        let batch = Array(records[start..<end])
                        
                        let (saved, skipped) = try await DatabaseManager.shared.saveTestRecords(batch)
                        totalSaved += saved
                        totalSkipped += skipped
                        
                        await MainActor.run {
                            saveProgress = Double(end) / Double(records.count)
                            saveResult = "Processing: \(end)/\(records.count) records..."
                        }
                    }
                    
                    await MainActor.run {
                        saveProgress = 1.0
                        saveResult = "Successfully saved \(totalSaved) records to database. \(totalSkipped) records skipped (duplicates)."
                    }
                case .migration:
                    let records = progress.validMigrationRecords
                    var totalSaved = 0
                    var totalSkipped = 0
                    let totalBatches = Int(ceil(Double(records.count) / Double(batchSize)))
                    
                    for batchIndex in 0..<totalBatches {
                        let start = batchIndex * batchSize
                        let end = min(start + batchSize, records.count)
                        let batch = Array(records[start..<end])
                        
                        let (saved, skipped) = try await DatabaseManager.shared.saveMigrationRecords(batch)
                        totalSaved += saved
                        totalSkipped += skipped
                        
                        await MainActor.run {
                            saveProgress = Double(end) / Double(records.count)
                            saveResult = "Processing: \(end)/\(records.count) records..."
                        }
                    }
                    
                    await MainActor.run {
                        saveProgress = 1.0
                        saveResult = "Successfully saved \(totalSaved) records to database. \(totalSkipped) records skipped (duplicates)."
                    }
                case .cluster:
                    let records = progress.validClusterRecords
                    var totalSaved = 0
                    var totalSkipped = 0
                    let totalBatches = Int(ceil(Double(records.count) / Double(batchSize)))
                    
                    for batchIndex in 0..<totalBatches {
                        let start = batchIndex * batchSize
                        let end = min(start + batchSize, records.count)
                        let batch = Array(records[start..<end])
                        
                        let (saved, skipped) = try await DatabaseManager.shared.saveClusterRecords(batch)
                        totalSaved += saved
                        totalSkipped += skipped
                        
                        await MainActor.run {
                            saveProgress = Double(end) / Double(records.count)
                            saveResult = "Processing: \(end)/\(records.count) records..."
                        }
                    }
                    
                    await MainActor.run {
                        saveProgress = 1.0
                        saveResult = "Successfully saved \(totalSaved) records to database. \(totalSkipped) records skipped (duplicates)."
                    }
                case .combined:
                    break  // Combined view doesn't have its own records to save
                }
            } catch {
                await MainActor.run {
                    saveProgress = 0.0
                    saveResult = "Error saving to database: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isSaving = false
            }
        }
    }
}

struct ValidPackageStatusRecordsView: View {
    let records: [PackageStatusData]
    let searchText: String
    
    var filteredRecords: [PackageStatusData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.packageStatus.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if records.isEmpty {
                Text("No package status records available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    ForEach(Array(filteredRecords.enumerated()), id: \.1.applicationName) { index, record in
                        HStack(spacing: 0) {
                            Text("#\(index + 1)")
                                .frame(width: 50, alignment: .leading)
                                .padding(.leading, 10)
                                .foregroundColor(.secondary)
                            Text(record.applicationName)
                                .frame(width: 250, alignment: .leading)
                            Text(record.packageStatus)
                                .frame(width: 150, alignment: .leading)
                            Text(record.packageReadinessDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
                                .frame(width: 150, alignment: .leading)
                            Text(DateFormatter.hrDateFormatter.string(from: record.importDate))
                                .frame(width: 150, alignment: .leading)
                            Text(record.importSet)
                                .frame(width: 200, alignment: .leading)
                        }
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 4)
                        .background(index % 2 == 0 ? Color.clear : Color(NSColor.separatorColor).opacity(0.05))
                    }
                }
            }
        }
    }
}

struct ValidMigrationRecordsView: View {
    let records: [MigrationData]
    let searchText: String
    
    var filteredRecords: [MigrationData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.applicationSuiteNew.localizedCaseInsensitiveContains(searchText) ||
            record.willBe.localizedCaseInsensitiveContains(searchText) ||
            record.inScopeOutScopeDivision.localizedCaseInsensitiveContains(searchText) ||
            record.migrationPlatform.localizedCaseInsensitiveContains(searchText) ||
            record.migrationApplicationReadiness.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#")
                            .frame(width: 50, alignment: .leading)
                            .padding(.leading, 25)
                        Text("Application Name")
                            .frame(width: 200, alignment: .leading)
                        Text("Application Suite New")
                            .frame(width: 200, alignment: .leading)
                        Text("Will Be")
                            .frame(width: 150, alignment: .leading)
                        Text("In/Out Scope Division")
                            .frame(width: 200, alignment: .leading)
                        Text("Migration Platform")
                            .frame(width: 200, alignment: .leading)
                        Text("Application Readiness")
                            .frame(width: 200, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.separatorColor).opacity(0.2))
                    .font(.headline)
                    
                    // Records
                    List {
                        ForEach(Array(filteredRecords.enumerated()), id: \.1.applicationName) { index, record in
                            HStack(spacing: 0) {
                                Text("#\(index + 1)")
                                    .frame(width: 50, alignment: .leading)
                                    .padding(.leading, 10)
                                    .foregroundColor(.secondary)
                                Text(record.applicationName)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.applicationSuiteNew)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.willBe)
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.inScopeOutScopeDivision)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.migrationPlatform)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.migrationApplicationReadiness)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
        }
    }
}

struct ValidTestRecordsView: View {
    let records: [TestingData]
    let searchText: String
    
    var filteredRecords: [TestingData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.testStatus.localizedCaseInsensitiveContains(searchText) ||
            record.testResult.localizedCaseInsensitiveContains(searchText) ||
            (record.testComments ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#")
                            .frame(width: 50, alignment: .leading)
                            .padding(.leading, 25)
                        Text("Application Name")
                            .frame(width: 200, alignment: .leading)
                        Text("Test Status")
                            .frame(width: 150, alignment: .leading)
                        Text("Test Date")
                            .frame(width: 150, alignment: .leading)
                        Text("Test Result")
                            .frame(width: 150, alignment: .leading)
                        Text("Comments")
                            .frame(width: 200, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.separatorColor).opacity(0.2))
                    .font(.headline)
                    
                    // Records
                    List {
                        ForEach(Array(filteredRecords.enumerated()), id: \.1.applicationName) { index, record in
                            HStack(spacing: 0) {
                                Text("#\(index + 1)")
                                    .frame(width: 50, alignment: .leading)
                                    .padding(.leading, 10)
                                    .foregroundColor(.secondary)
                                Text(record.applicationName)
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.testStatus)
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                Text(DateFormatter.hrDateFormatter.string(from: record.testDate))
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.testResult)
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.testComments ?? "")
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
        }
    }
}

struct ValidClusterRecordsView: View {
    let records: [ClusterData]
    let searchText: String
    
    var filteredRecords: [ClusterData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.department.localizedCaseInsensitiveContains(searchText) ||
            record.departmentSimple.localizedCaseInsensitiveContains(searchText) ||
            record.domain.localizedCaseInsensitiveContains(searchText) ||
            record.migrationCluster.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Department")
                    .frame(width: 200, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 200, alignment: .leading)
                Text("Domain")
                    .frame(width: 150, alignment: .leading)
                Text("Migration Cluster")
                    .frame(width: 200, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRecords) { record in
                        HStack(spacing: 0) {
                            Text(record.department)
                                .frame(width: 200, alignment: .leading)
                            Text(record.departmentSimple)
                                .frame(width: 200, alignment: .leading)
                            Text(record.domain)
                                .frame(width: 150, alignment: .leading)
                            Text(record.migrationCluster)
                                .frame(width: 200, alignment: .leading)
                        }
                        .frame(height: 18)
                        .font(.system(size: 11))
                        .background(filteredRecords.firstIndex(where: { $0.id == record.id })!.isMultiple(of: 2) ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    }
                }
            }
        }
    }
}

#Preview {
    ValidationView(progress: ImportProgress())
} 