import SwiftUI
import UniformTypeIdentifiers
import GRDB

struct BaselineAccountsView: View {
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var totalUniqueAccounts = 0
    @State private var totalMatchingAccounts = 0
    @State private var totalPastLeaveDateAccounts = 0
    @State private var pastLeaveDateAccounts: Set<String> = []
    @State private var accountsWithoutHR: Set<String> = []
    @State private var showingSavePanel = false
    @State private var exportType: ExportType = .pastLeaveDate
    @State private var lastUpdateTime = Date()
    @State private var lastADImportDate: Date?
    @State private var lastHRImportDate: Date?
    
    // Add permission property
    var hasDownloadPermission: Bool = true
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private var totalAccounts: Int {
        totalMatchingAccounts + totalPastLeaveDateAccounts + totalUniqueAccounts
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Top section with timestamps and pie chart
            HStack(alignment: .top, spacing: 20) {
                // Timestamps on the left
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
                .padding(.top)
                
                Spacer()
                
                // Pie Chart on the right
                VStack {
                    Text("Account Distribution")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    ZStack {
                        if totalAccounts > 0 {
                            PieSlice(startAngle: 0,
                                    endAngle: 360 * Double(totalMatchingAccounts) / Double(totalAccounts))
                                .fill(Color.green.opacity(0.1))
                            
                            PieSlice(startAngle: 360 * Double(totalMatchingAccounts) / Double(totalAccounts),
                                    endAngle: 360 * Double(totalMatchingAccounts + totalPastLeaveDateAccounts) / Double(totalAccounts))
                                .fill(Color.orange.opacity(0.1))
                            
                            PieSlice(startAngle: 360 * Double(totalMatchingAccounts + totalPastLeaveDateAccounts) / Double(totalAccounts),
                                    endAngle: 360)
                                .fill(Color.red.opacity(0.1))
                        } else {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        }
                    }
                    .frame(width: 200, height: 200)
                    
                    // Legend
                    HStack(spacing: 20) {
                        if totalAccounts > 0 {
                            legendItem(color: .green, label: "Matching", percentage: Double(totalMatchingAccounts) / Double(totalAccounts))
                            legendItem(color: .orange, label: "Past Leave Date", percentage: Double(totalPastLeaveDateAccounts) / Double(totalAccounts))
                            legendItem(color: .red, label: "Missing HR", percentage: Double(totalUniqueAccounts) / Double(totalAccounts))
                        } else {
                            Text("No accounts to display")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
            .padding(.horizontal)
            
            // Total Boxes
            HStack(spacing: 20) {
                // Matching accounts (green box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Matching Accounts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalMatchingAccounts)")
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
                
                // Past leave date accounts (orange box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Past Leave Date Accounts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalPastLeaveDateAccounts)")
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .frame(width: 300, height: 100)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                
                // Accounts without HR data (red box)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accounts in AD but not in HR")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(totalUniqueAccounts)")
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
                            exportType = .pastLeaveDate
                            showingSavePanel = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Past Leave Date Accounts")
                            }
                            .padding()
                            .frame(width: 300)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            exportType = .missingHR
                            showingSavePanel = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Missing HR Accounts")
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
            document: AccountsCSVDocument(
                accounts: exportType == .pastLeaveDate ? pastLeaveDateAccounts : accountsWithoutHR,
                timestamp: lastUpdateTime,
                type: exportType,
                adImportDate: lastADImportDate,
                hrImportDate: lastHRImportDate
            ),
            contentType: .commaSeparatedText,
            defaultFilename: "\(exportType == .pastLeaveDate ? "past_leave_date_accounts" : "missing_hr_accounts")_\(formatDateForFilename(lastUpdateTime)).csv"
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
            
            // Get last import dates from AD and HR records
            let adImportDate = try await DatabaseManager.shared.getLatestImportDate(from: "ad_records")
            let hrImportDate = try await DatabaseManager.shared.getLatestImportDate(from: "hr_records")
            
            // Filter for unique accounts that have no HR data
            accountsWithoutHR = Set(combinedRecords
                .filter { record in
                    record.department == nil || record.department?.isEmpty == true
                }
                .map { $0.systemAccount }
            )
            
            // Filter for accounts that have both AD and HR data (excluding past leave dates), then get unique system accounts
            let matchingAccounts = Set(combinedRecords
                .filter { record in
                    record.department != nil && 
                    !record.department!.isEmpty &&
                    (record.leaveDate == nil || record.leaveDate! >= Date())
                }
                .map { $0.systemAccount }
            )
            
            // Filter for unique accounts with leave date before today
            pastLeaveDateAccounts = Set(combinedRecords
                .filter { record in
                    if let leaveDate = record.leaveDate {
                        return leaveDate < Date()
                    }
                    return false
                }
                .map { $0.systemAccount }
            )
            
            print("Total combined records: \(combinedRecords.count)")
            print("Accounts without HR data: \(accountsWithoutHR.count)")
            print("Unique matching accounts: \(matchingAccounts.count)")
            print("Unique past leave date accounts: \(pastLeaveDateAccounts.count)")
            
            await MainActor.run {
                lastADImportDate = adImportDate
                lastHRImportDate = hrImportDate
                totalUniqueAccounts = accountsWithoutHR.count
                totalMatchingAccounts = matchingAccounts.count
                totalPastLeaveDateAccounts = pastLeaveDateAccounts.count
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
            Text("\(label) (\(totalAccounts > 0 ? Int(percentage * 100) : 0)%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack {
        // With download permissions
        BaselineAccountsView(hasDownloadPermission: true)
            .frame(height: 400)
        
        // Without download permissions
        BaselineAccountsView(hasDownloadPermission: false)
            .frame(height: 400)
    }
} 