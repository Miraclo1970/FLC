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
    @State private var migrationRecords: [MigrationRecord] = []
    @State private var clusterRecords: [ClusterRecord] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 1000 // Increased page size for faster loading
    let refresh: (() async -> Void)?
    @State private var autoLoadingEnabled = true
    @State private var loadingTask: Task<Void, Never>?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    let dismiss: () -> Void
    
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
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Picker("Data Type", selection: $selectedDataType) {
                        Text("Combined Data").tag(ImportProgress.DataType.combined)
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
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .onChange(of: selectedDataType, initial: false) { oldValue, newValue in
                    Task {
                        // Only reload if we're not switching to combined view or if combined records are empty
                        if newValue != .combined || combinedRecords.isEmpty {
                            await loadData(resetData: true)
                        }
                    }
                }
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
            .padding()
            
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
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
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
                                .frame(minWidth: 800)
                            case .hr:
                                DatabaseHRRecordsView(records: filteredHRRecords)
                                    .environment(\.refresh, {
                                        Task {
                                            await loadData(resetData: true)
                                        }
                                    })
                                    .frame(minWidth: 800)
                            case .combined:
                                DatabaseCombinedRecordsView(
                                    records: filteredCombinedRecords
                                )
                                .environment(\.refresh, {
                                    Task {
                                        await loadData(resetData: true)
                                    }
                                })
                                .frame(minWidth: 800)
                            case .packageStatus:
                                DatabasePackageRecordsView(records: filteredPackageRecords)
                                    .environment(\.refresh, {
                                        Task {
                                            await loadData(resetData: true)
                                        }
                                    })
                                    .frame(minWidth: 800)
                            case .testing:
                                DatabaseTestRecordsView(records: filteredTestRecords)
                                    .environment(\.refresh, {
                                        Task {
                                            await loadData(resetData: true)
                                        }
                                    })
                                    .frame(minWidth: 800)
                            case .migration:
                                DatabaseMigrationRecordsView(records: filteredMigrationRecords)
                                    .environment(\.refresh, {
                                        Task {
                                            await loadData(resetData: true)
                                        }
                                    })
                                    .frame(minWidth: 800)
                            case .cluster:
                                DatabaseClusterRecordsView(records: filteredClusterRecords) {
                                    Task {
                                        await loadData(resetData: false)
                                    }
                                }
                                .frame(minWidth: 800)
                            }
                        }
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
                    case .migration: return "Total Records: \(migrationRecords.count)"
                    case .cluster: return "Total Records: \(clusterRecords.count)"
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
            // Only load data if we don't have any records yet
            if combinedRecords.isEmpty && selectedDataType == .combined {
                // Cancel any existing loading task
                loadingTask?.cancel()
                // Create new loading task
                loadingTask = Task {
                    await loadData(resetData: true)
                }
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
            (record.testingPlanDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.testDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredMigrationRecords: [MigrationRecord] {
        if searchText.isEmpty {
            return migrationRecords
        }
        return migrationRecords.filter { record in
            record.applicationName.localizedCaseInsensitiveContains(searchText) ||
            record.applicationSuiteNew.localizedCaseInsensitiveContains(searchText) ||
            record.willBe.localizedCaseInsensitiveContains(searchText) ||
            record.inScopeOutScopeDivision.localizedCaseInsensitiveContains(searchText) ||
            record.migrationPlatform.localizedCaseInsensitiveContains(searchText) ||
            record.migrationApplicationReadiness.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredClusterRecords: [ClusterRecord] {
        if searchText.isEmpty {
            return clusterRecords
        }
        return clusterRecords.filter { record in
            record.department.localizedCaseInsensitiveContains(searchText) ||
            (record.departmentSimple ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.domain ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.migrationCluster ?? "").localizedCaseInsensitiveContains(searchText)
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
            migrationRecords = []
            clusterRecords = []
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
                print("Loading combined records...")
                // Only regenerate if resetData is true AND we don't have any combined records yet
                if resetData && combinedRecords.isEmpty {
                    let count = try await DatabaseManager.shared.generateCombinedRecords()
                    if !Task.isCancelled {  // Check after generation
                        print("Generated \(count) combined records")
                    }
                }
                
                let newRecords = try await DatabaseManager.shared.fetchCombinedRecords()
                if !Task.isCancelled {  // Check again after fetch
                    combinedRecords = newRecords
                    print("Loaded \(newRecords.count) combined records")
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
            case .migration:
                print("Loading migration records page \(currentPage)...")
                // First, ensure migration records are generated
                if resetData {
                    // Migration records don't need generation as they are imported directly
                    print("Migration records don't require generation")
                }
                
                let newRecords = try await DatabaseManager.shared.fetchMigrationRecords(limit: pageSize)
                if !Task.isCancelled {  // Check again after fetch
                    if resetData {
                        migrationRecords = newRecords
                    } else {
                        migrationRecords.append(contentsOf: newRecords)
                    }
                    hasMoreData = !newRecords.isEmpty && newRecords.count == pageSize
                    
                    // If we have more data, immediately load the next batch
                    if hasMoreData && !resetData && !Task.isCancelled {
                        currentPage += 1
                        await loadData(resetData: false)
                    }
                    
                    print("Loaded \(newRecords.count) migration records, total: \(migrationRecords.count), hasMore: \(hasMoreData)")
                }
            case .cluster:
                print("Loading cluster records page \(currentPage)...")
                let newRecords = try await DatabaseManager.shared.fetchClusterRecords(limit: 10000, offset: 0)  // Load all at once
                if !Task.isCancelled {  // Check again after fetch
                    clusterRecords = newRecords
                    hasMoreData = false  // No more data to load
                    print("Loaded \(newRecords.count) cluster records")
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
                case .migration:
                    try await DatabaseManager.shared.clearMigrationRecords()
                    migrationRecords = []
                case .cluster:
                    try await DatabaseManager.shared.clearClusterRecords()
                    clusterRecords = []
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
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("ID")
                    .frame(width: 80, alignment: .leading)
                    .padding(.leading, 16)
                Text("System Account")
                    .frame(width: 150, alignment: .leading)
                Text("Department")
                    .frame(width: 200, alignment: .leading)
                Text("Job Role")
                    .frame(width: 150, alignment: .leading)
                Text("Division")
                    .frame(width: 150, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 150, alignment: .leading)
                Text("Leave Date")
                    .frame(width: 150, alignment: .leading)
                Text("Import Date")
                    .frame(width: 200, alignment: .leading)
                Text("Import Set")
                    .frame(width: 150, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(records, id: \.id) { record in
                        HStack(spacing: 0) {
                            Text(String(format: "%.0f", Double(record.id ?? -1)))
                                .frame(width: 80, alignment: .leading)
                                .padding(.leading, 16)
                            Text(record.systemAccount)
                                .frame(width: 150, alignment: .leading)
                            Text(record.department ?? "N/A")
                                .frame(width: 200, alignment: .leading)
                            Text(record.jobRole ?? "N/A")
                                .frame(width: 150, alignment: .leading)
                            Text(record.division ?? "N/A")
                                .frame(width: 150, alignment: .leading)
                            Text(record.departmentSimple ?? "N/A")
                                .frame(width: 150, alignment: .leading)
                            Text(record.leaveDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                                .frame(width: 150, alignment: .leading)
                            Text(dateFormatter.string(from: record.importDate))
                                .frame(width: 200, alignment: .leading)
                            Text(record.importSet)
                                .frame(width: 150, alignment: .leading)
                        }
                        .frame(height: rowHeight)
                        .font(.system(size: 11))
                    }
                }
            }
        }
    }
}

struct DatabaseCombinedRecordsView: View {
    let records: [CombinedRecord]
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var headerView: some View {
        HStack(spacing: 0) {
            // ID Column
            Text("ID")
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 16)
            
            // AD Data Section
            HStack(spacing: 0) {
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
            .background(Color.blue.opacity(0.05))
            
            // HR Data Section
            HStack(spacing: 0) {
                Text("Department")
                    .frame(width: 150, alignment: .leading)
                Text("Job Role")
                    .frame(width: 150, alignment: .leading)
                Text("Division")
                    .frame(width: 150, alignment: .leading)
                Text("Leave Date")
                    .frame(width: 150, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 150, alignment: .leading)
                Text("Domain")
                    .frame(width: 150, alignment: .leading)
            }
            .background(Color.green.opacity(0.05))
            
            // Package Status Section
            HStack(spacing: 0) {
                Text("Package Status")
                    .frame(width: 150, alignment: .leading)
                Text("Package Readiness")
                    .frame(width: 200, alignment: .leading)
            }
            .background(Color.orange.opacity(0.05))
            
            // Test Status Section
            HStack(spacing: 0) {
                Text("Test Status")
                    .frame(width: 150, alignment: .leading)
                Text("Test Readiness")
                    .frame(width: 200, alignment: .leading)
                Text("Test Result")
                    .frame(width: 150, alignment: .leading)
                Text("Testing Plan Date")
                    .frame(width: 200, alignment: .leading)
            }
            .background(Color.purple.opacity(0.05))
            
            // Migration Section
            HStack(spacing: 0) {
                Text("New Application")
                    .frame(width: 150, alignment: .leading)
                Text("New Suite")
                    .frame(width: 150, alignment: .leading)
                Text("Will be")
                    .frame(width: 150, alignment: .leading)
                Text("In/Out Scope")
                    .frame(width: 200, alignment: .leading)
                Text("Platform")
                    .frame(width: 150, alignment: .leading)
                Text("Migration Readiness")
                    .frame(width: 200, alignment: .leading)
            }
            .background(Color.yellow.opacity(0.05))
            
            // Department and Migration Section
            HStack(spacing: 0) {
                Text("Department Simple")
                    .frame(width: 150, alignment: .leading)
                Text("Domain")
                    .frame(width: 150, alignment: .leading)
                Text("Migration Cluster")
                    .frame(width: 150, alignment: .leading)
                Text("Migration Cluster Readiness")
                    .frame(width: 150, alignment: .leading)
            }
            .background(Color.indigo.opacity(0.05))
            
            // Metadata Section
            HStack(spacing: 0) {
                Text("Import Date")
                    .frame(width: 200, alignment: .leading)
                Text("Import Set")
                    .frame(width: 150, alignment: .leading)
            }
            .background(Color.gray.opacity(0.05))
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    var dataRowsView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(records, id: \.id) { record in
                    DataRowView(record: record, dateFormatter: dateFormatter, rowHeight: rowHeight)
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    headerView
                    dataRowsView
                }
            }
        }
    }
}

struct DataRowView: View {
    let record: CombinedRecord
    let dateFormatter: DateFormatter
    let rowHeight: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            // ID Column
            Text(String(format: "%.0f", Double(record.id ?? -1)))
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 16)
                .font(.system(size: 11))
            
            // AD Data Section
            HStack(spacing: 0) {
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
            HStack(spacing: 0) {
                Text(record.department ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.jobRole ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.division ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.leaveDate.map { dateFormatter.string(from: $0) } ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.departmentSimple ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.domain ?? "")
                    .frame(width: 150, alignment: .leading)
            }
            .font(.system(size: 11))
            .background(Color.green.opacity(0.05))
            
            // Package Status Section
            HStack(spacing: 0) {
                Text(record.applicationPackageStatus ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.applicationPackageReadinessDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "")
                    .frame(width: 200, alignment: .leading)
            }
            .font(.system(size: 11))
            .background(Color.orange.opacity(0.05))
            
            // Test Status Section
            HStack(spacing: 0) {
                Text(record.applicationTestStatus ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.applicationTestReadinessDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "")
                    .frame(width: 200, alignment: .leading)
                Text(record.testResult ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.testingPlanDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "")
                    .frame(width: 200, alignment: .leading)
            }
            .font(.system(size: 11))
            .background(Color.purple.opacity(0.05))
            
            // Migration Section
            HStack(spacing: 0) {
                Text(record.applicationNew ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.applicationSuiteNew ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.willBe ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.inScopeOutScopeDivision ?? "")
                    .frame(width: 200, alignment: .leading)
                Text(record.migrationPlatform ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.migrationApplicationReadiness ?? "")
                    .frame(width: 200, alignment: .leading)
            }
            .font(.system(size: 11))
            .background(Color.yellow.opacity(0.05))
            
            // Department and Migration Section
            HStack(spacing: 0) {
                Text(record.departmentSimple ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.domain ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.migrationCluster ?? "")
                    .frame(width: 150, alignment: .leading)
                Text(record.migrationClusterReadiness ?? "")
                    .frame(width: 150, alignment: .leading)
            }
            .font(.system(size: 11))
            .background(Color.indigo.opacity(0.05))
            
            // Metadata Section
            HStack(spacing: 0) {
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
                        Text("Application Name")
                            .frame(width: 200, alignment: .leading)
                        Text("Test Status")
                            .frame(width: 150, alignment: .leading)
                        Text("Test Date")
                            .frame(width: 200, alignment: .leading)
                        Text("Test Result")
                            .frame(width: 150, alignment: .leading)
                        Text("Testing Plan Date")
                            .frame(width: 200, alignment: .leading)
                        Text("Import Date")
                            .frame(width: 200, alignment: .leading)
                        Text("Import Set")
                            .frame(width: 150, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                    .font(.system(size: 11, weight: .bold))
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    Text(record.applicationName)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testStatus)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testResult)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.testingPlanDate.map { DateFormatter.hrDateFormatter.string(from: $0) } ?? "N/A")
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

struct DatabaseMigrationRecordsView: View {
    let records: [MigrationRecord]
    private let rowHeight: CGFloat = 18
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("ID")
                    .frame(width: 80, alignment: .leading)
                    .padding(.leading, 16)
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
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(records, id: \.id) { record in
                        HStack(spacing: 0) {
                            Text(String(format: "%.0f", Double(record.id ?? -1)))
                                .frame(width: 80, alignment: .leading)
                                .padding(.leading, 16)
                            Text(record.applicationName)
                                .frame(width: 200, alignment: .leading)
                            Text(record.applicationSuiteNew)
                                .frame(width: 200, alignment: .leading)
                            Text(record.willBe)
                                .frame(width: 150, alignment: .leading)
                            Text(record.inScopeOutScopeDivision)
                                .frame(width: 200, alignment: .leading)
                            Text(record.migrationPlatform)
                                .frame(width: 200, alignment: .leading)
                            Text(record.migrationApplicationReadiness)
                                .frame(width: 200, alignment: .leading)
                        }
                        .frame(height: rowHeight)
                        .font(.system(size: 11))
                    }
                }
            }
        }
    }
}

struct DatabaseClusterRecordsView: View {
    let records: [ClusterRecord]
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
            // Header
            HStack(spacing: 0) {
                Text("ID")
                    .frame(width: 80, alignment: .leading)
                    .padding(.leading, 16)
                Text("Department")
                    .frame(width: 200, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 200, alignment: .leading)
                Text("Domain")
                    .frame(width: 150, alignment: .leading)
                Text("Migration Cluster")
                    .frame(width: 200, alignment: .leading)
                Text("Migration Cluster Readiness")
                    .frame(width: 200, alignment: .leading)
                Text("Import Date")
                    .frame(width: 200, alignment: .leading)
                Text("Import Set")
                    .frame(width: 200, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(records, id: \.id) { record in
                        HStack(spacing: 0) {
                            Text("\(record.id ?? 0)")
                                .frame(width: 80, alignment: .leading)
                                .padding(.leading, 16)
                            Text(record.department)
                                .frame(width: 200, alignment: .leading)
                            Text(record.departmentSimple ?? "")
                                .frame(width: 200, alignment: .leading)
                            Text(record.domain ?? "")
                                .frame(width: 150, alignment: .leading)
                            Text(record.migrationCluster ?? "")
                                .frame(width: 200, alignment: .leading)
                            Text(record.migrationClusterReadiness ?? "")
                                .frame(width: 200, alignment: .leading)
                            Text(dateFormatter.string(from: record.importDate))
                                .frame(width: 200, alignment: .leading)
                            Text(record.importSet)
                                .frame(width: 200, alignment: .leading)
                        }
                        .frame(height: rowHeight)
                        .font(.system(size: 11))
                        .background(records.firstIndex(where: { $0.id == record.id })!.isMultiple(of: 2) ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    }
                }
            }
            .onAppear {
                // Start auto-loading timer
                autoLoadTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    onScrolledNearBottom()
                }
            }
            .onDisappear {
                // Clean up timer
                autoLoadTimer?.invalidate()
                autoLoadTimer = nil
            }
        }
    }
}

#Preview {
    DatabaseContentView(
        refresh: {},
        dismiss: {}
    )
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