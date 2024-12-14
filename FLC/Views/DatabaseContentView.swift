import SwiftUI

struct DatabaseContentView: View {
    @State private var selectedDataType = ImportProgress.DataType.ad
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var adRecords: [ADRecord] = []
    @State private var hrRecords: [HRRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Data Type Picker with enhanced visibility
            VStack(spacing: 8) {
                Text("Select Data Type")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Data Type", selection: $selectedDataType) {
                    Text("AD Data").tag(ImportProgress.DataType.ad)
                    Text("HR Data").tag(ImportProgress.DataType.hr)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .onChange(of: selectedDataType) { oldValue, newValue in
                    Task {
                        await loadData()
                    }
                }
            }
            .padding(.horizontal)
            
            // Stats Cards
            HStack(spacing: 20) {
                DashboardCard(
                    title: "Total Records",
                    value: "\(selectedDataType == .ad ? adRecords.count : hrRecords.count)",
                    icon: "doc.text"
                )
            }
            .padding()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search in database records...", text: $searchText)
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
            
            if isLoading {
                ProgressView("Loading records...")
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                // Records View
                Group {
                    if selectedDataType == .ad {
                        DatabaseADRecordsView(records: filteredADRecords)
                    } else {
                        DatabaseHRRecordsView(records: filteredHRRecords)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadData()
        }
    }
    
    private var filteredADRecords: [ADRecord] {
        if searchText.isEmpty {
            return adRecords
        }
        return adRecords.filter { record in
            record.adGroup.localizedCaseInsensitiveContains(searchText) ||
            record.systemAccount.localizedCaseInsensitiveContains(searchText) ||
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.applicationSuite.localizedCaseInsensitiveContains(searchText) ||
            record.otap.localizedCaseInsensitiveContains(searchText) ||
            record.critical.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredHRRecords: [HRRecord] {
        if searchText.isEmpty {
            return hrRecords
        }
        return hrRecords.filter { record in
            record.systemAccount.localizedCaseInsensitiveContains(searchText) ||
            (record.department ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.jobRole ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.division ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.employeeNumber ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch selectedDataType {
            case .ad:
                adRecords = try await DatabaseManager.shared.fetchADRecords()
            case .hr:
                hrRecords = try await DatabaseManager.shared.fetchHRRecords()
            }
        } catch {
            errorMessage = "Error loading records: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct DatabaseADRecordsView: View {
    let records: [ADRecord]
    
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
                        Text("Import Date")
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.separatorColor).opacity(0.2))
                    .font(.headline)
                    
                    // Records
                    List {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            HStack(spacing: 0) {
                                Text("#\(index + 1)")
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
                                Text(record.importDate.formatted())
                                    .frame(width: 150, alignment: .leading)
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

struct DatabaseHRRecordsView: View {
    let records: [HRRecord]
    
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
                        Text("Job Role")
                            .frame(width: 200, alignment: .leading)
                        Text("Division")
                            .frame(width: 200, alignment: .leading)
                        Text("Leave Date")
                            .frame(width: 120, alignment: .leading)
                        Text("Employee Number")
                            .frame(width: 150, alignment: .leading)
                        Text("Import Date")
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.separatorColor).opacity(0.2))
                    .font(.headline)
                    
                    // Records
                    List {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
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
                                Text(record.jobRole ?? "N/A")
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.division ?? "N/A")
                                    .frame(width: 200, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.leaveDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
                                    .frame(width: 120, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.employeeNumber ?? "N/A")
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                Text(record.importDate.formatted())
                                    .frame(width: 150, alignment: .leading)
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

#Preview {
    DatabaseContentView()
} 