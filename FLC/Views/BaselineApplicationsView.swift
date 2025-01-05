import SwiftUI
import UniformTypeIdentifiers
import GRDB

struct BaselineApplicationsView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var totalApplications = 0
    @State private var totalWithPackageStatus = 0
    @State private var totalWithTestStatus = 0
    @State private var totalADGroups = 0  // For total unique AD groups
    @State private var totalProblematicLines = 0  // For lines with no HR or past leave date
    @State private var applicationsWithoutStatus: Set<String> = []
    @State private var applicationsWithoutName: Set<String> = []
    @State private var showingSavePanel = false
    @State private var lastUpdateTime = Date()
    @State private var lastADImportDate: Date?
    @State private var lastHRImportDate: Date?
    @State private var exportType: ExportType = .withoutStatus
    
    // OTAP filter states
    @State private var selectedOTAP: Set<String> = ["P"]
    private let otapOptions = ["A", "OT", "P", "Prullenbak", "TW", "VDI"]
    
    var hasDownloadPermission: Bool = true
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private var totalCount: Int {
        totalApplications
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // OTAP Filter section
            VStack(alignment: .leading, spacing: 10) {
                Text("OTAP Filter")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 15) {
                    ForEach(otapOptions, id: \.self) { option in
                        Toggle(isOn: Binding(
                            get: { selectedOTAP.contains(option) },
                            set: { isSelected in
                                if isSelected {
                                    selectedOTAP.insert(option)
                                } else {
                                    selectedOTAP.remove(option)
                                }
                                Task {
                                    await loadBaselineData()
                                }
                            }
                        )) {
                            Text(option)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal)
            
            // Top section with timestamps and pie chart
            HStack(alignment: .top, spacing: 20) {
                // Left side: Timestamps and Pie Chart
                VStack(alignment: .leading, spacing: 20) {
                    // Timestamps
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Baseline check: \(dateFormatter.string(from: lastUpdateTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let adDate = lastADImportDate {
                            Text("Last AD import: \(dateFormatter.string(from: adDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let hrDate = lastHRImportDate {
                            Text("Last HR import: \(dateFormatter.string(from: hrDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Pie Chart
                    VStack {
                        Text("Application Status Distribution")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        ZStack {
                            if totalCount > 0 {
                                // All Applications (green)
                                PieSlice(startAngle: 0,
                                        endAngle: 360 * Double(totalApplications) / Double(totalCount + totalWithTestStatus))
                                    .fill(Color.green.opacity(0.1))
                                
                                // Applications without name (yellow)
                                PieSlice(startAngle: 360 * Double(totalApplications) / Double(totalCount + totalWithTestStatus),
                                        endAngle: 360)
                                    .fill(Color.yellow.opacity(0.1))
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            }
                        }
                        .frame(width: 200, height: 200)
                        
                        // Legend
                        HStack(spacing: 20) {
                            if totalCount > 0 {
                                legendItem(color: .green, label: "All Applications", percentage: Double(totalApplications) / Double(totalCount + totalWithTestStatus))
                                legendItem(color: .yellow, label: "Applications without Name", percentage: Double(totalWithTestStatus) / Double(totalCount + totalWithTestStatus))
                            } else {
                                Text("No applications to display")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding()
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Total Boxes
            HStack(spacing: 20) {
                // Total AD Groups (blue box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total AD Groups")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalADGroups)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                
                // All Applications (green box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("All Applications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalApplications)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
                
                // Applications without name (yellow box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Applications without Name")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalWithTestStatus)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
                
                // Applications without status (red box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("AD Groups without HR or Past Leave")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalProblematicLines)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding()
            
            // Download section (only shown if user has permission)
            if hasDownloadPermission {
                VStack(spacing: 10) {
                    Text("Download Options")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Button(action: { 
                            exportType = .withoutName
                            showingSavePanel = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Applications without Name")
                            }
                            .padding()
                            .frame(width: 300)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            exportType = .withoutStatus
                            showingSavePanel = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("AD Groups without HR or Past Leave")
                            }
                            .padding()
                            .frame(width: 300)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadBaselineData()
        }
        .fileExporter(
            isPresented: $showingSavePanel,
            document: ApplicationsCSVDocument(
                applications: exportType == .withoutName ? applicationsWithoutName : applicationsWithoutStatus,
                timestamp: lastUpdateTime,
                exportType: exportType,
                adImportDate: lastADImportDate,
                hrImportDate: lastHRImportDate
            ),
            contentType: .commaSeparatedText,
            defaultFilename: "\(exportType == .withoutName ? "applications_without_name" : "applications_without_status")_\(formatDateForFilename(lastUpdateTime)).csv"
        ) { result in
            if case .failure(let error) = result {
                print("Export error: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
    
    private func loadBaselineData() async {
        isLoading = true
        do {
            // Update timestamp first
            await MainActor.run {
                lastUpdateTime = Date()
            }
            
            // Get combined records
            let combinedRecords = try await DatabaseManager.shared.fetchCombinedRecords()
            print("Total records in database: \(combinedRecords.count)")
            
            // Get last import dates from AD and HR records
            let adImportDate = try await DatabaseManager.shared.getLatestImportDate(from: "ad_records")
            let hrImportDate = try await DatabaseManager.shared.getLatestImportDate(from: "hr_records")
            
            // For application tracking
            var applications = Set<String>()
            var withPackage = Set<String>()
            var withoutName = Set<String>()
            var noHROrPastLeave = Set<String>()  // Keep this for export functionality
            var allADGroups = Set<String>()  // Track unique AD groups
            
            // Count raw lines for problematic records
            var noHRMatchLines = 0
            var pastLeaveDateLines = 0
            
            // First pass: Count lines with no HR match and track unique AD groups
            for record in combinedRecords {
                guard selectedOTAP.contains(record.otap) else { continue }
                
                // Track all unique AD groups
                allADGroups.insert(record.adGroup)
                
                // Count raw lines for no HR match
                if record.department == nil || record.department?.isEmpty == true {
                    noHRMatchLines += 1
                    noHROrPastLeave.insert("\(record.applicationName)|\(record.adGroup)")  // Keep for export
                }
            }
            
            // Second pass: Count lines with past leave date
            for record in combinedRecords {
                guard selectedOTAP.contains(record.otap) else { continue }
                
                // Only check records WITH HR match for leave date
                if record.department != nil && !record.department!.isEmpty {
                    if record.leaveDate != nil && record.leaveDate! < Date() {
                        pastLeaveDateLines += 1
                        noHROrPastLeave.insert("\(record.applicationName)|\(record.adGroup)")  // Keep for export
                    }
                }
            }
            
            // Third pass: Process application status counts
            for record in combinedRecords {
                guard selectedOTAP.contains(record.otap) else { continue }
                
                let appKey = "\(record.applicationName)|\(record.adGroup)"
                
                if record.applicationName.isEmpty || record.applicationName == "#N/A" {
                    withoutName.insert(appKey)
                } else {
                    applications.insert(appKey)
                    if let packageStatus = record.applicationPackageStatus, !packageStatus.isEmpty {
                        withPackage.insert(appKey)
                    }
                }
            }
            
            print("Debug counts:")
            print("Selected OTAP values: \(selectedOTAP)")
            print("Total unique AD groups: \(allADGroups.count)")
            print("Lines with no HR match: \(noHRMatchLines)")
            print("Lines with past leave date: \(pastLeaveDateLines)")
            print("Total problematic lines: \(noHRMatchLines + pastLeaveDateLines)")
            
            await MainActor.run {
                lastADImportDate = adImportDate
                lastHRImportDate = hrImportDate
                totalApplications = applications.count
                totalWithPackageStatus = withPackage.count
                totalWithTestStatus = withoutName.count
                totalADGroups = allADGroups.count  // Total unique AD groups
                totalProblematicLines = noHRMatchLines + pastLeaveDateLines  // Total problematic lines
                applicationsWithoutName = withoutName
                applicationsWithoutStatus = noHROrPastLeave  // Keep for export functionality
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func legendItem(color: Color, label: String, percentage: Double) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
            Text("\(label) (\(totalCount > 0 ? Int(percentage * 100) : 0)%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var applications: Set<String>
    var timestamp: Date
    var exportType: ExportType
    var adImportDate: Date?
    var hrImportDate: Date?
    
    init(applications: Set<String>, timestamp: Date, exportType: ExportType, adImportDate: Date? = nil, hrImportDate: Date? = nil) {
        self.applications = applications
        self.timestamp = timestamp
        self.exportType = exportType
        self.adImportDate = adImportDate
        self.hrImportDate = hrImportDate
    }
    
    init(configuration: ReadConfiguration) throws {
        applications = []
        timestamp = Date()
        exportType = .withoutStatus
        adImportDate = nil
        hrImportDate = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        let title = switch exportType {
            case .withoutName: "Applications without Name"
            case .withoutStatus: "Applications without Status"
            default: "Applications"
        }
        
        var csvString = """
            \(title)
            Baseline check: \(dateFormatter.string(from: timestamp))
            """
        
        if let adDate = adImportDate {
            csvString += "\nLast AD import: \(dateFormatter.string(from: adDate))"
        }
        
        if let hrDate = hrImportDate {
            csvString += "\nLast HR import: \(dateFormatter.string(from: hrDate))"
        }
        
        if exportType == .withoutName {
            csvString += "\n\nAD Group\n"
            csvString += applications.sorted().joined(separator: "\n")
        } else {
            csvString += "\n\nApplication Name,AD Group\n"
            csvString += applications.sorted().map { key -> String in
                let parts = key.split(separator: "|")
                return "\(parts[0]),\(parts[1])"
            }.joined(separator: "\n")
        }
        
        let data = csvString.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    BaselineApplicationsView()
} 