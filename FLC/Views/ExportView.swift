import SwiftUI

struct ExportView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var selectedFormat: ExportFormat = .csv
    @State private var isExporting = false
    @State private var exportError: String?
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case excel = "Excel"
        case json = "JSON"
        
        var icon: String {
            switch self {
            case .csv: return "doc.text"
            case .excel: return "tablecells"
            case .json: return "curlybraces"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .excel: return "xlsx"
            case .json: return "json"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Export Database")
                    .font(.title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            
            // Main Content
            VStack(alignment: .leading, spacing: 20) {
                // Format Selection
                GroupBox("Export Format") {
                    HStack(spacing: 20) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Button(action: { selectedFormat = format }) {
                                VStack(spacing: 8) {
                                    Image(systemName: format.icon)
                                        .font(.title2)
                                    Text(format.rawValue)
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 80)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedFormat == format ? .accentColor : .secondary)
                        }
                    }
                    .padding()
                }
                
                // Export Button
                Button(action: exportCombinedView) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Export Combined View", systemImage: "arrow.down.doc")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
                
                if let error = exportError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
                
                // Info Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("The export will include all records from the Combined View", systemImage: "info.circle")
                        Text("Available formats:")
                            .font(.caption)
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Label(format.rawValue, systemImage: format.icon)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func exportCombinedView() {
        isExporting = true
        exportError = nil
        
        Task {
            do {
                // Get save location from user
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.init(filenameExtension: selectedFormat.fileExtension)!]
                panel.nameFieldStringValue = "combined_export.\(selectedFormat.fileExtension)"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = panel.url {
                    // Fetch combined records
                    let records = try await databaseManager.fetchCombinedRecords()
                    
                    // Export based on selected format
                    switch selectedFormat {
                    case .csv:
                        try await exportAsCSV(records: records, to: url)
                    case .excel:
                        try await exportAsExcel(records: records, to: url)
                    case .json:
                        try await exportAsJSON(records: records, to: url)
                    }
                }
            } catch {
                exportError = "Export failed: \(error.localizedDescription)"
            }
            
            isExporting = false
        }
    }
    
    private func exportAsCSV(records: [CombinedRecord], to url: URL) async throws {
        // Create header with all fields
        let headers = [
            // AD Data fields
            "AD Group", "Application Name", "Application Suite", "OTAP", "Critical",
            // HR Data fields
            "System Account", "Department", "Job Role", "Division", "Leave Date",
            // Package tracking fields
            "Package Status", "Package Readiness Date",
            // Test tracking fields
            "Test Status", "Test Readiness Date",
            // Migration fields
            "New Application", "New Application Suite", "Will Be",
            "In/Out Scope Division", "Migration Platform", "Migration Application Readiness",
            // Department and Migration fields
            "Department Simple", "Domain", "Migration Cluster", "Migration Cluster Readiness",
            // Metadata
            "Import Date", "Import Set"
        ]
        
        var csvString = headers.joined(separator: ",") + "\n"
        
        for record in records {
            // Break down field collection into smaller parts
            let adFields = [
                record.adGroup,
                record.applicationName,
                record.applicationSuite,
                record.otap,
                record.critical
            ]
            
            let hrFields = [
                record.systemAccount,
                record.department ?? "",
                record.jobRole ?? "",
                record.division ?? "",
                record.leaveDate?.description ?? ""
            ]
            
            let packageFields = [
                record.applicationPackageStatus ?? "",
                record.applicationPackageReadinessDate?.description ?? ""
            ]
            
            let testFields = [
                record.applicationTestStatus ?? "",
                record.applicationTestReadinessDate?.description ?? ""
            ]
            
            let migrationFields = [
                record.applicationNew ?? "",
                record.applicationSuiteNew ?? "",
                record.willBe ?? "",
                record.inScopeOutScopeDivision ?? "",
                record.migrationPlatform ?? "",
                record.migrationApplicationReadiness ?? ""
            ]
            
            let departmentFields = [
                record.departmentSimple ?? "",
                record.domain ?? "",
                record.migrationCluster ?? "",
                record.migrationClusterReadiness ?? ""
            ]
            
            let metadataFields = [
                record.importDate.description,
                record.importSet
            ]
            
            // Combine all field groups
            let fields = adFields + hrFields + packageFields + testFields + migrationFields + departmentFields + metadataFields
            
            // Process each field to handle quotes and commas
            let processedFields = fields.map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            
            // Join the fields with commas
            let row = processedFields.joined(separator: ",")
            csvString += row + "\n"
        }
        
        try csvString.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportAsJSON(records: [CombinedRecord], to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(records)
        try data.write(to: url)
    }
    
    private func exportAsExcel(records: [CombinedRecord], to url: URL) async throws {
        // For now, fallback to CSV as Excel export requires additional setup
        try await exportAsCSV(records: records, to: url)
    }
} 