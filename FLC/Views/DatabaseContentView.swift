import SwiftUI

struct DatabaseContentView: View {
    @State private var selectedDataType = ImportProgress.DataType.combined
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var adRecords: [ADRecord] = []
    @State private var hrRecords: [HRRecord] = []
    @State private var combinedRecords: [CombinedRecord] = []
    @State private var packageRecords: [PackageRecord] = []
    @State private var testRecords: [TestRecord] = []
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
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Data Type Picker with enhanced visibility
            VStack(spacing: 8) {
                Text("Select Data Type")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Data Type", selection: $selectedDataType) {
                    Text("Combined Data").tag(ImportProgress.DataType.combined)
                    Text("AD Data").tag(ImportProgress.DataType.ad)
                    Text("HR Data").tag(ImportProgress.DataType.hr)
                    Text("Package Status").tag(ImportProgress.DataType.packageStatus)
                    Text("Testing").tag(ImportProgress.DataType.testing)
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
                        case .packageStatus: return "\(packageRecords.count)"
                        case .testing: return "\(testRecords.count)"
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
                    case .packageStatus: return packageRecords.isEmpty
                    case .testing: return testRecords.isEmpty
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
                    case .packageStatus:
                        DatabasePackageRecordsView(records: filteredPackageRecords)
                            .environment(\.refresh, {
                                Task {
                                    await loadData(resetData: true)
                                }
                            })
                    case .testing:
                        DatabaseTestRecordsView(records: filteredTestRecords)
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
                    case .packageStatus: return "Total Records: \(packageRecords.count)"
                    case .testing: return "Total Records: \(testRecords.count)"
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
                clearData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all records? This action cannot be undone.")
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
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
            (record.division ?? "").localizedCaseInsensitiveContains(searchText)
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
            (record.division ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredPackageRecords: [PackageRecord] {
        if searchText.isEmpty {
            return packageRecords
        }
        return packageRecords.filter { record in
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.packageStatus.localizedCaseInsensitiveContains(searchText) ||
            record.packageReadinessDate.map { (date: Date) in dateFormatter.string(from: date) }.map { (str: String) in str.localizedCaseInsensitiveContains(searchText) } ?? false
        }
    }
    
    private var filteredTestRecords: [TestRecord] {
        if searchText.isEmpty {
            return testRecords
        }
        return testRecords.filter { record in
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.testStatus.localizedCaseInsensitiveContains(searchText) ||
            record.testResult.localizedCaseInsensitiveContains(searchText) ||
            (record.testComments ?? "").localizedCaseInsensitiveContains(searchText) ||
            dateFormatter.string(from: record.testDate).localizedCaseInsensitiveContains(searchText)
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
            packageRecords = []
            testRecords = []
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
            case .packageStatus:
                print("Loading package records page \(currentPage)...")
                // First, ensure package records are generated
                if resetData {
                    let count = try await DatabaseManager.shared.generatePackageRecords()
                    if !Task.isCancelled {  // Check after generation
                        print("Generated \(count) package records")
                    }
                }
                
                let newRecords = try await DatabaseManager.shared.fetchPackageRecords(limit: pageSize, offset: currentPage * pageSize)
                if !Task.isCancelled {  // Check again after fetch
                    if resetData {
                        packageRecords = newRecords
                    } else {
                        packageRecords.append(contentsOf: newRecords)
                    }
                    hasMoreData = !newRecords.isEmpty && newRecords.count == pageSize
                    
                    // If we have more data, immediately load the next batch
                    if hasMoreData && !resetData && !Task.isCancelled {
                        currentPage += 1
                        await loadData(resetData: false)
                    }
                    
                    print("Loaded \(newRecords.count) package records, total: \(packageRecords.count), hasMore: \(hasMoreData)")
                }
            case .testing:
                print("Loading test records page \(currentPage)...")
                // First, ensure test records are generated
                if resetData {
                    let count = try await DatabaseManager.shared.generateTestRecords()
                    if !Task.isCancelled {  // Check after generation
                        print("Generated \(count) test records")
                    }
                }
                
                let newRecords = try await DatabaseManager.shared.fetchTestRecords(limit: pageSize, offset: currentPage * pageSize)
                if !Task.isCancelled {  // Check again after fetch
                    if resetData {
                        testRecords = newRecords
                    } else {
                        testRecords.append(contentsOf: newRecords)
                    }
                    hasMoreData = !newRecords.isEmpty && newRecords.count == pageSize
                    
                    // If we have more data, immediately load the next batch
                    if hasMoreData && !resetData && !Task.isCancelled {
                        currentPage += 1
                        await loadData(resetData: false)
                    }
                    
                    print("Loaded \(newRecords.count) test records, total: \(testRecords.count), hasMore: \(hasMoreData)")
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
    
    private func clearData() {
        Task {
            do {
                switch selectedDataType {
                case .ad:
                    try await DatabaseManager.shared.clearADRecords()
                    adRecords = []
                case .hr:
                    try await DatabaseManager.shared.clearHRRecords()
                    hrRecords = []
                case .packageStatus:
                    try await DatabaseManager.shared.clearPackageRecords()
                    packageRecords = []
                case .testing:
                    try await DatabaseManager.shared.clearTestRecords()
                    testRecords = []
                case .combined:
                    try await DatabaseManager.shared.clearCombinedRecords()
                    combinedRecords = []
                }
                showAlert(title: "Success", message: "All records cleared successfully")
            } catch {
                showAlert(title: "Error", message: "Failed to clear records: \(error.localizedDescription)")
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
    
    var body: some View {
        Table(records, selection: .constant(Set<HRRecord.ID>())) {
            TableColumn("System Account", value: \.systemAccount)
            TableColumn("Department") { record in
                Text(record.department ?? "N/A")
            }
            TableColumn("Job Role") { record in
                Text(record.jobRole ?? "N/A")
            }
            TableColumn("Division") { record in
                Text(record.division ?? "N/A")
            }
            TableColumn("Department Simple") { record in
                Text(record.departmentSimple ?? "N/A")
            }
            TableColumn("Leave Date") { record in
                Text(record.leaveDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
            }
            TableColumn("Import Date") { record in
                Text(DateFormatter.hrDateFormatter.string(from: record.importDate))
            }
            TableColumn("Import Set", value: \.importSet)
        }
    }
}

struct DatabaseCombinedRecordsView: View {
    let records: [CombinedRecord]
    let onScrolledNearBottom: () -> Void
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        // ID Column
                        Text("ID")
                            .frame(width: 80, alignment: .leading)
                            .padding(.leading, 16)
                            .font(.system(size: 11))
                        
                        // AD Data Section
                        Group {
                            Text("AD Group")
                                .frame(width: 150, alignment: .leading)
                            Text("System Account")
                                .frame(width: 150, alignment: .leading)
                            Text("Application")
                                .frame(width: 150, alignment: .leading)
                            Text("Suite")
                                .frame(width: 150, alignment: .leading)
                            Text("OTAP")
                                .frame(width: 80, alignment: .leading)
                            Text("Critical")
                                .frame(width: 80, alignment: .leading)
                        }
                        .font(.system(size: 11))
                        .background(Color.blue.opacity(0.1))
                        
                        // HR Data Section
                        Group {
                            Text("Department")
                                .frame(width: 150, alignment: .leading)
                            Text("Job Role")
                                .frame(width: 150, alignment: .leading)
                            Text("Division")
                                .frame(width: 150, alignment: .leading)
                            Text("Leave Date")
                                .frame(width: 100, alignment: .leading)
                            Text("Department Simple")
                                .frame(width: 150, alignment: .leading)
                        }
                        .font(.system(size: 11))
                        .background(Color.green.opacity(0.1))
                        
                        // Package Tracking Section
                        Group {
                            Text("Package Status")
                                .frame(width: 120, alignment: .leading)
                            Text("Package Ready Date")
                                .frame(width: 120, alignment: .leading)
                        }
                        .font(.system(size: 11))
                        .background(Color.orange.opacity(0.1))
                        
                        // Test Tracking Section
                        Group {
                            Text("Test Status")
                                .frame(width: 120, alignment: .leading)
                            Text("Test Ready Date")
                                .frame(width: 120, alignment: .leading)
                        }
                        .font(.system(size: 11))
                        .background(Color.purple.opacity(0.1))
                        
                        // Department and Migration Section
                        Group {
                            Text("Dept Simple")
                                .frame(width: 120, alignment: .leading)
                            Text("Migration Cluster")
                                .frame(width: 120, alignment: .leading)
                            Text("Migration Readiness")
                                .frame(width: 120, alignment: .leading)
                        }
                        .font(.system(size: 11))
                        .background(Color.yellow.opacity(0.1))
                        
                        // Metadata Section
                        Group {
                            Text("Import Date")
                                .frame(width: 200, alignment: .leading)
                            Text("Import Set")
                                .frame(width: 150, alignment: .leading)
                        }
                        .font(.system(size: 11))
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
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.systemAccount)
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.applicationName)
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.applicationSuite)
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.otap)
                                            .frame(width: 80, alignment: .leading)
                                        Text(record.critical)
                                            .frame(width: 80, alignment: .leading)
                                    }
                                    .font(.system(size: 11))
                                    .background(Color.blue.opacity(0.05))
                                    
                                    // HR Data Section
                                    Group {
                                        Text(record.department ?? "N/A")
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.jobRole ?? "N/A")
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.division ?? "N/A")
                                            .frame(width: 150, alignment: .leading)
                                        Text(record.leaveDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                                            .frame(width: 100, alignment: .leading)
                                        Text(record.departmentSimple ?? "N/A")
                                            .frame(width: 150, alignment: .leading)
                                    }
                                    .font(.system(size: 11))
                                    .background(Color.green.opacity(0.05))
                                    
                                    // Package Tracking Section
                                    Group {
                                        Text(record.applicationPackageStatus ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                        Text(record.applicationPackageReadinessDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                    }
                                    .font(.system(size: 11))
                                    .background(Color.orange.opacity(0.05))
                                    
                                    // Test Tracking Section
                                    Group {
                                        Text(record.applicationTestStatus ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                        Text(record.applicationTestReadinessDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                    }
                                    .font(.system(size: 11))
                                    .background(Color.purple.opacity(0.05))
                                    
                                    // Department and Migration Section
                                    Group {
                                        Text(record.departmentSimple ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                        Text(record.migrationCluster ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                        Text(record.migrationReadiness ?? "N/A")
                                            .frame(width: 120, alignment: .leading)
                                    }
                                    .font(.system(size: 11))
                                    .background(Color.yellow.opacity(0.05))
                                    
                                    // Metadata Section
                                    Group {
                                        Text(dateFormatter.string(from: record.importDate))
                                            .frame(width: 200, alignment: .leading)
                                        Text(record.importSet)
                                            .frame(width: 150, alignment: .leading)
                                    }
                                    .font(.system(size: 11))
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
    }
}

struct DatabasePackageRecordsView: View {
    let records: [PackageRecord]
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
                        Text("Application Name")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Package Status")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Package Readiness Date")
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
                                    Text(record.applicationName)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.packageStatus)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.packageReadinessDate.map { dateFormatter.string(from: $0) } ?? "N/A")
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
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DatabaseTestRecordsView: View {
    let records: [TestRecord]
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
                        Text("Application Name")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Test Status")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Test Date")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Test Result")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Test Comments")
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
                                    Text(record.applicationName)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testStatus)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(dateFormatter.string(from: record.testDate))
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testResult)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testComments ?? "N/A")
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