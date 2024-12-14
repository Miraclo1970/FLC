import SwiftUI

struct DatabaseContentView: View {
    @State private var selectedDataType = ImportProgress.DataType.ad
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var adRecords: [ADRecord] = []
    @State private var hrRecords: [HRRecord] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 1000 // Increased page size for faster loading
    @Environment(\.refresh) private var refresh
    @State private var autoLoadingEnabled = true
    
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
                        await loadData(resetData: true)
                    }
                }
            }
            .padding(.horizontal)
            
            // Stats Cards and Clear Button
            HStack(spacing: 20) {
                DashboardCard(
                    title: "Total Records",
                    value: "\(selectedDataType == .ad ? adRecords.count : hrRecords.count)",
                    icon: "doc.text"
                )
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Label("Clear All Records", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .disabled(selectedDataType == .ad ? adRecords.isEmpty : hrRecords.isEmpty)
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
                // Records View with improved loading
                Group {
                    if selectedDataType == .ad {
                        DatabaseADRecordsView(
                            records: filteredADRecords,
                            onScrolledNearBottom: {
                                if !isLoadingMore && hasMoreData {
                                    Task {
                                        await loadMoreADRecords()
                                    }
                                }
                            }
                        )
                        .environment(\.refresh, {
                            Task {
                                await loadData(resetData: true)
                            }
                        })
                    } else {
                        DatabaseHRRecordsView(records: filteredHRRecords)
                            .environment(\.refresh, {
                                Task {
                                    await loadData(resetData: true)
                                }
                            })
                    }
                }
                
                if isLoadingMore {
                    ProgressView("Loading more records...")
                        .padding()
                }
                
                // Show total records count
                Text("Total Records: \(selectedDataType == .ad ? adRecords.count : hrRecords.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadData(resetData: true)
        }
        .alert("Clear All Records", isPresented: $showingDeleteAlert) {
            Button("Clear All", role: .destructive) {
                Task {
                    do {
                        if selectedDataType == .ad {
                            try await DatabaseManager.shared.clearADRecords()
                        } else {
                            try await DatabaseManager.shared.clearHRRecords()
                        }
                        await loadData(resetData: true)
                    } catch {
                        errorMessage = "Error clearing records: \(error.localizedDescription)"
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all \(selectedDataType == .ad ? "AD" : "HR") records? This action cannot be undone.")
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
    
    private func loadData(resetData: Bool = false) async {
        if resetData {
            isLoading = true
            errorMessage = nil
            currentPage = 0
            adRecords = []
            hrRecords = []
            hasMoreData = true
        }
        
        do {
            switch selectedDataType {
            case .ad:
                print("Loading AD records page \(currentPage)...")
                let newRecords = try await DatabaseManager.shared.fetchADRecords(limit: pageSize, offset: currentPage * pageSize)
                if resetData {
                    adRecords = newRecords
                } else {
                    adRecords.append(contentsOf: newRecords)
                }
                hasMoreData = !newRecords.isEmpty && newRecords.count == pageSize
                
                // If we have more data, immediately load the next batch
                if hasMoreData && !resetData {
                    currentPage += 1
                    await loadData(resetData: false)
                }
                
                print("Loaded \(newRecords.count) AD records, total: \(adRecords.count), hasMore: \(hasMoreData)")
            case .hr:
                print("Loading HR records...")
                hrRecords = try await DatabaseManager.shared.fetchHRRecords()
                print("Loaded \(hrRecords.count) HR records")
            }
        } catch {
            print("Error loading records: \(error)")
            errorMessage = "Error loading records: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func loadMoreADRecords() async {
        guard !isLoadingMore, hasMoreData, selectedDataType == .ad else { return }
        
        print("Loading more AD records, current page: \(currentPage), total records: \(adRecords.count)")
        isLoadingMore = true
        currentPage += 1
        await loadData(resetData: false)
        isLoadingMore = false
    }
}

struct DatabaseADRecordsView: View {
    let records: [ADRecord]
    private let rowHeight: CGFloat = 30
    let onScrolledNearBottom: () -> Void
    @State private var autoLoadTimer: Timer? = nil
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("ID")
                            .frame(width: 80, alignment: .leading)
                            .padding(.leading, 25)
                        Text("AD Group")
                            .frame(width: 300, alignment: .leading)
                        Text("System Account")
                            .frame(width: 200, alignment: .leading)
                        Text("Application")
                            .frame(width: 250, alignment: .leading)
                        Text("Suite")
                            .frame(width: 200, alignment: .leading)
                        Text("Import Date")
                            .frame(width: 200, alignment: .leading)
                        Text("Import Set")
                            .frame(width: 150, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                    .border(Color.gray.opacity(0.2), width: 1)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    Text(String(format: "%.0f", Double(record.id ?? -1)))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 25)
                                    Text(record.adGroup)
                                        .frame(width: 300, alignment: .leading)
                                    Text(record.systemAccount)
                                        .frame(width: 200, alignment: .leading)
                                    Text(record.applicationName)
                                        .frame(width: 250, alignment: .leading)
                                    Text(record.applicationSuite)
                                        .frame(width: 200, alignment: .leading)
                                    Text(dateFormatter.string(from: record.importDate))
                                        .frame(width: 200, alignment: .leading)
                                    Text(record.importSet)
                                        .frame(width: 150, alignment: .leading)
                                }
                                .frame(height: rowHeight)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .onAppear {
                                    // If this is one of the last 20 items, trigger loading more
                                    let thresholdIndex = records.count - 20
                                    if let recordIndex = records.firstIndex(where: { $0.id == record.id }),
                                       recordIndex >= thresholdIndex {
                                        onScrolledNearBottom()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            startAutoLoadTimer()
        }
        .onDisappear {
            stopAutoLoadTimer()
        }
    }
    
    private func startAutoLoadTimer() {
        // Stop any existing timer
        stopAutoLoadTimer()
        
        // Create a new timer that fires every 0.2 seconds
        autoLoadTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            if !records.isEmpty {
                onScrolledNearBottom()
            }
        }
    }
    
    private func stopAutoLoadTimer() {
        autoLoadTimer?.invalidate()
        autoLoadTimer = nil
    }
}

// Preference keys for view and content heights
struct ViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DatabaseHRRecordsView: View {
    let records: [HRRecord]
    private let rowHeight: CGFloat = 30
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("ID")
                            .frame(width: 80, alignment: .leading)
                            .padding(.leading, 25)
                        Text("System Account")
                            .frame(width: 200, alignment: .leading)
                        Text("Department")
                            .frame(width: 200, alignment: .leading)
                        Text("Job Role")
                            .frame(width: 200, alignment: .leading)
                        Text("Division")
                            .frame(width: 200, alignment: .leading)
                        Text("Import Date")
                            .frame(width: 200, alignment: .leading)
                        Text("Import Set")
                            .frame(width: 150, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                    .border(Color.gray.opacity(0.2), width: 1)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    Text(String(format: "%.0f", Double(record.id ?? -1)))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 25)
                                    Text(record.systemAccount)
                                        .frame(width: 200, alignment: .leading)
                                    Text(record.department ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                    Text(record.jobRole ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                    Text(record.division ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                    Text(dateFormatter.string(from: record.importDate))
                                        .frame(width: 200, alignment: .leading)
                                    Text(record.importSet)
                                        .frame(width: 150, alignment: .leading)
                                }
                                .frame(height: rowHeight)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
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

// Environment key for refresh action
private struct RefreshKey: EnvironmentKey {
    static let defaultValue: (() async -> Void)? = nil
}

extension EnvironmentValues {
    var refresh: (() async -> Void)? {
        get { self[RefreshKey.self] }
        set { self[RefreshKey.self] = newValue }
    }
} 