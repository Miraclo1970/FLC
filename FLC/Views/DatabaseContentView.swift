import SwiftUI

struct DatabaseContentView: View {
    @State private var selectedDataType = ImportProgress.DataType.ad
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var adRecords: [ADRecord] = []
    @State private var hrRecords: [HRRecord] = []
    @State private var combinedRecords: [CombinedRecord] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 1000 // Increased page size for faster loading
    @Environment(\.refresh) private var refresh
    @State private var autoLoadingEnabled = true
    @State private var loadingTask: Task<Void, Never>?
    
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
                    Text("Combined Data").tag(ImportProgress.DataType.combined)
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
                    value: {
                        switch selectedDataType {
                        case .ad: return "\(adRecords.count)"
                        case .hr: return "\(hrRecords.count)"
                        case .combined: return "\(combinedRecords.count)"
                        }
                    }(),
                    icon: "doc.text"
                )
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Label("Clear All Records", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .disabled({
                    switch selectedDataType {
                    case .ad: return adRecords.isEmpty
                    case .hr: return hrRecords.isEmpty
                    case .combined: return combinedRecords.isEmpty
                    }
                }())
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
                    .frame(maxWidth: 200)
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                // Records View with improved loading
                Group {
                    switch selectedDataType {
                    case .ad:
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
                    case .hr:
                        DatabaseHRRecordsView(records: filteredHRRecords)
                            .environment(\.refresh, {
                                Task {
                                    await loadData(resetData: true)
                                }
                            })
                    case .combined:
                        DatabaseCombinedRecordsView(
                            records: filteredCombinedRecords,
                            onScrolledNearBottom: {
                                if !isLoadingMore && hasMoreData {
                                    Task {
                                        await loadMoreCombinedRecords()
                                    }
                                }
                            }
                        )
                        .environment(\.refresh, {
                            Task {
                                await loadData(resetData: true)
                            }
                        })
                    }
                }
                
                if isLoadingMore {
                    ProgressView("Loading more records...")
                        .frame(maxWidth: 200)
                        .padding()
                }
                
                // Show total records count
                Text({
                    switch selectedDataType {
                    case .ad: return "Total Records: \(adRecords.count)"
                    case .hr: return "Total Records: \(hrRecords.count)"
                    case .combined: return "Total Records: \(combinedRecords.count)"
                    }
                }())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            // Cancel any existing loading task
            loadingTask?.cancel()
            // Create new loading task
            loadingTask = Task {
                await loadData(resetData: true)
            }
        }
        .onDisappear {
            // Cancel loading task when view disappears
            loadingTask?.cancel()
            loadingTask = nil
        }
        .alert("Clear All Records", isPresented: $showingDeleteAlert) {
            Button("Clear All", role: .destructive) {
                Task {
                    do {
                        switch selectedDataType {
                        case .ad:
                            try await DatabaseManager.shared.clearADRecords()
                        case .hr:
                            try await DatabaseManager.shared.clearHRRecords()
                        case .combined:
                            try await DatabaseManager.shared.clearCombinedRecords()
                        }
                        await loadData(resetData: true)
                    } catch {
                        errorMessage = "Error clearing records: \(error.localizedDescription)"
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text({
                switch selectedDataType {
                case .ad: return "Are you sure you want to clear all AD records? This action cannot be undone."
                case .hr: return "Are you sure you want to clear all HR records? This action cannot be undone."
                case .combined: return "Are you sure you want to clear all combined records? This action cannot be undone."
                }
            }())
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
    
    private var filteredCombinedRecords: [CombinedRecord] {
        if searchText.isEmpty {
            return combinedRecords
        }
        return combinedRecords.filter { record in
            record.adGroup.localizedCaseInsensitiveContains(searchText) ||
            record.systemAccount.localizedCaseInsensitiveContains(searchText) ||
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.applicationSuite.localizedCaseInsensitiveContains(searchText) ||
            record.otap.localizedCaseInsensitiveContains(searchText) ||
            record.critical.localizedCaseInsensitiveContains(searchText) ||
            (record.department ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.jobRole ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.division ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.employeeNumber ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadData(resetData: Bool = false) async {
        // Check if task is cancelled
        guard !Task.isCancelled else { return }
        
        if resetData {
            isLoading = true
            errorMessage = nil
            currentPage = 0
            adRecords = []
            hrRecords = []
            combinedRecords = []
            hasMoreData = true
        }
        
        do {
            switch selectedDataType {
            case .ad:
                print("Loading AD records page \(currentPage)...")
                let newRecords = try await DatabaseManager.shared.fetchADRecords(limit: pageSize, offset: currentPage * pageSize)
                if !Task.isCancelled {  // Check again after async operation
                    if resetData {
                        adRecords = newRecords
                    } else {
                        adRecords.append(contentsOf: newRecords)
                    }
                    hasMoreData = !newRecords.isEmpty && newRecords.count == pageSize
                    
                    // If we have more data, immediately load the next batch
                    if hasMoreData && !resetData && !Task.isCancelled {
                        currentPage += 1
                        await loadData(resetData: false)
                    }
                    
                    print("Loaded \(newRecords.count) AD records, total: \(adRecords.count), hasMore: \(hasMoreData)")
                }
            case .hr:
                print("Loading HR records...")
                let records = try await DatabaseManager.shared.fetchHRRecords()
                if !Task.isCancelled {  // Check again after async operation
                    hrRecords = records
                    print("Loaded \(hrRecords.count) HR records")
                }
            case .combined:
                print("Loading combined records page \(currentPage)...")
                // First, ensure combined records are generated
                if resetData {
                    let count = try await DatabaseManager.shared.generateCombinedRecords()
                    if !Task.isCancelled {  // Check after generation
                        print("Generated \(count) combined records")
                    }
                }
                
                let newRecords = try await DatabaseManager.shared.fetchCombinedRecords(limit: pageSize, offset: currentPage * pageSize)
                if !Task.isCancelled {  // Check again after fetch
                    if resetData {
                        combinedRecords = newRecords
                    } else {
                        combinedRecords.append(contentsOf: newRecords)
                    }
                    hasMoreData = !newRecords.isEmpty && newRecords.count == pageSize
                    
                    // If we have more data, immediately load the next batch
                    if hasMoreData && !resetData && !Task.isCancelled {
                        currentPage += 1
                        await loadData(resetData: false)
                    }
                    
                    print("Loaded \(newRecords.count) combined records, total: \(combinedRecords.count), hasMore: \(hasMoreData)")
                }
            }
        } catch {
            if !Task.isCancelled {  // Only show error if not cancelled
                print("Error loading records: \(error)")
                errorMessage = "Error loading records: \(error.localizedDescription)"
            }
        }
        
        if !Task.isCancelled {  // Only update loading state if not cancelled
            isLoading = false
        }
    }
    
    private func loadMoreADRecords() async {
        guard !isLoadingMore, hasMoreData, selectedDataType == .ad else { return }
        
        loadingTask?.cancel()  // Cancel any existing loading task
        loadingTask = Task {
            print("Loading more AD records, current page: \(currentPage), total records: \(adRecords.count)")
            isLoadingMore = true
            currentPage += 1
            await loadData(resetData: false)
            if !Task.isCancelled {
                isLoadingMore = false
            }
        }
    }
    
    private func loadMoreCombinedRecords() async {
        guard !isLoadingMore, hasMoreData, selectedDataType == .combined else { return }
        
        loadingTask?.cancel()  // Cancel any existing loading task
        loadingTask = Task {
            print("Loading more combined records, current page: \(currentPage), total records: \(combinedRecords.count)")
            isLoadingMore = true
            currentPage += 1
            await loadData(resetData: false)
            if !Task.isCancelled {
                isLoadingMore = false
            }
        }
    }
}

struct DatabaseADRecordsView: View {
    let records: [ADRecord]
    private let rowHeight: CGFloat = 18
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
                            .padding(.leading, 16)
                            .font(.system(size: 11))
                        Text("AD Group")
                            .frame(width: 300, alignment: .leading)
                            .font(.system(size: 11))
                        Text("System Account")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Application")
                            .frame(width: 250, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Suite")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Import Date")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Import Set")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                    }
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .border(Color.gray.opacity(0.2), width: 1)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    Text(String(format: "%.0f", Double(record.id ?? -1)))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 16)
                                        .font(.system(size: 11))
                                    Text(record.adGroup)
                                        .frame(width: 300, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.systemAccount)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.applicationName)
                                        .frame(width: 250, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.applicationSuite)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(dateFormatter.string(from: record.importDate))
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.importSet)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                }
                                .frame(height: rowHeight)
                                .padding(.vertical, 0)
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
    private let rowHeight: CGFloat = 18
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
                            .padding(.leading, 16)
                            .font(.system(size: 11))
                        Text("System Account")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Department")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Job Role")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Division")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Leave Date")
                            .frame(width: 120, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Employee #")
                            .frame(width: 120, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Import Date")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Import Set")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                    }
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .border(Color.gray.opacity(0.2), width: 1)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    Text(String(format: "%.0f", Double(record.id ?? -1)))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 16)
                                        .font(.system(size: 11))
                                    Text(record.systemAccount)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.department ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.jobRole ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.division ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.leaveDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
                                        .frame(width: 120, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.employeeNumber ?? "N/A")
                                        .frame(width: 120, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(dateFormatter.string(from: record.importDate))
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.importSet)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                }
                                .frame(height: rowHeight)
                                .padding(.vertical, 0)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DatabaseCombinedRecordsView: View {
    let records: [CombinedRecord]
    private let rowHeight: CGFloat = 18
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
                    // Header with sections
                    HStack(spacing: 0) {
                        // ID Column
                        Text("ID")
                            .frame(width: 80, alignment: .leading)
                            .padding(.leading, 16)
                            .font(.system(size: 11))
                        
                        // AD Data Section
                        Group {
                            Text("AD Group")
                                .frame(width: 250, alignment: .leading)
                                .font(.system(size: 11))
                            Text("System Account")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Application")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Suite")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("OTAP")
                                .frame(width: 100, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Critical")
                                .frame(width: 100, alignment: .leading)
                                .font(.system(size: 11))
                        }
                        .background(Color.blue.opacity(0.1))
                        
                        // HR Data Section
                        Group {
                            Text("Department")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Job Role")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Division")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Leave Date")
                                .frame(width: 120, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Employee #")
                                .frame(width: 120, alignment: .leading)
                                .font(.system(size: 11))
                        }
                        .background(Color.green.opacity(0.1))
                        
                        // Metadata Section
                        Group {
                            Text("Import Date")
                                .frame(width: 200, alignment: .leading)
                                .font(.system(size: 11))
                            Text("Import Set")
                                .frame(width: 150, alignment: .leading)
                                .font(.system(size: 11))
                        }
                        .background(Color.gray.opacity(0.1))
                    }
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .border(Color.gray.opacity(0.2), width: 1)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    // ID Column
                                    Text(String(format: "%.0f", Double(record.id ?? -1)))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 16)
                                        .font(.system(size: 11))
                                    
                                    // AD Data Section
                                    Group {
                                        Text(record.adGroup)
                                            .frame(width: 250, alignment: .leading)
                                            .font(.system(size: 11))
                                        Text(record.systemAccount)
                                            .frame(width: 200, alignment: .leading)
                                            .font(.system(size: 11))
                                        Text(record.applicationName)
                                            .frame(width: 200, alignment: .leading)
                                            .font(.system(size: 11))
                                        Text(record.applicationSuite)
                                            .frame(width: 200, alignment: .leading)
                                            .font(.system(size: 11))
                                        Text(record.otap)
                                            .frame(width: 100, alignment: .leading)
                                            .font(.system(size: 11))
                                        Text(record.critical)
                                            .frame(width: 100, alignment: .leading)
                                            .font(.system(size: 11))
                                    }
                                    .background(Color.blue.opacity(0.05))
                                    
                                    // HR Data Section
                                    Group {
                                        Text(record.department ?? "N/A")
                                            .frame(width: 200, alignment: .leading)
                                            .foregroundColor(record.department == nil ? .secondary : .primary)
                                            .font(.system(size: 11))
                                        Text(record.jobRole ?? "N/A")
                                            .frame(width: 200, alignment: .leading)
                                            .foregroundColor(record.jobRole == nil ? .secondary : .primary)
                                            .font(.system(size: 11))
                                        Text(record.division ?? "N/A")
                                            .frame(width: 200, alignment: .leading)
                                            .foregroundColor(record.division == nil ? .secondary : .primary)
                                            .font(.system(size: 11))
                                        Text(record.leaveDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                            .foregroundColor(record.leaveDate == nil ? .secondary : .primary)
                                            .font(.system(size: 11))
                                        Text(record.employeeNumber ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                            .foregroundColor(record.employeeNumber == nil ? .secondary : .primary)
                                            .font(.system(size: 11))
                                    }
                                    .background(Color.green.opacity(0.05))
                                    
                                    // Metadata Section
                                    Group {
                                        Text(dateFormatter.string(from: record.importDate))
                                            .frame(width: 200, alignment: .leading)
                                            .font(.system(size: 11))
                                        Text(record.importSet)
                                            .frame(width: 150, alignment: .leading)
                                            .font(.system(size: 11))
                                    }
                                    .background(Color.gray.opacity(0.05))
                                }
                                .frame(height: rowHeight)
                                .padding(.vertical, 0)
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