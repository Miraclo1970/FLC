import SwiftUI

struct QueryView: View {
    @State private var selectedDataType = ImportProgress.DataType.ad
    @State private var selectedField = ""
    @State private var selectedOperator = "equals"
    @State private var filterValue = ""
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var queryResults: [Any] = []
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // Field types
    enum FieldType {
        case text
        case date
        case boolean
    }
    
    // Field definitions with their types
    let fieldTypes: [String: FieldType] = [
        // AD fields
        "AD Group": .text,
        "System Account": .text,
        "Application Name": .text,
        "Application Suite": .text,
        "OTAP": .text,
        "Critical": .boolean,
        
        // HR fields
        "Department": .text,
        "Job Role": .text,
        "Division": .text,
        "Leave Date": .date,
        
        // Package Status fields
        "Package Status": .text,
        "Package Readiness Date": .date
    ]
    
    // Available operators based on field type
    var availableOperators: [String] {
        guard let fieldType = fieldTypes[selectedField] else { return [] }
        
        switch fieldType {
        case .text:
            return [
                "equals",
                "not equals",
                "contains",
                "not contains",
                "starts with",
                "ends with",
                "is empty",
                "is not empty"
            ]
        case .date:
            return [
                "equals",
                "not equals",
                "before",
                "after",
                "is empty",
                "is not empty"
            ]
        case .boolean:
            return [
                "equals",
                "not equals"
            ]
        }
    }
    
    // Dynamic fields based on data type
    var availableFields: [String] {
        switch selectedDataType {
        case .ad:
            return ["AD Group", "System Account", "Application Name", "Application Suite", "OTAP", "Critical"]
        case .hr:
            return ["System Account", "Department", "Job Role", "Division", "Leave Date"]
        case .combined:
            return ["AD Group", "System Account", "Application Name", "Application Suite", "OTAP", "Critical",
                   "Department", "Job Role", "Division", "Leave Date"]
        case .packageStatus:
            return ["Application Name", "Package Status", "Package Readiness Date"]
        case .testing:
            return ["Application Name", "Test Status", "Test Date", "Test Result", "Test Comments"]
        case .migration:
            return ["Application Name", "Application Suite New", "Will Be", "In/Out Scope Division", "Migration Platform", "Migration Application Readiness"]
        case .cluster:
            return ["Department", "Department Simple", "Domain", "Migration Cluster"]
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Data Type Selector
            VStack(spacing: 8) {
                Text("Select Data Source")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Data Source", selection: $selectedDataType) {
                    Text("AD Data").tag(ImportProgress.DataType.ad)
                    Text("HR Data").tag(ImportProgress.DataType.hr)
                    Text("Combined Data").tag(ImportProgress.DataType.combined)
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
                .onChange(of: selectedDataType) { oldValue, newValue in
                    // Reset field selection when data type changes
                    selectedField = ""
                    filterValue = ""
                }
            }
            .padding(.horizontal)
            
            // Query Builder Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Build Query")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                // Field Selection
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Field")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Field", selection: $selectedField) {
                            Text("Select field").tag("")
                            ForEach(availableFields, id: \.self) { field in
                                Text(field).tag(field)
                            }
                        }
                        .frame(width: 200)
                        .onChange(of: selectedField) { oldValue, newValue in
                            // Reset operator when field changes
                            if !availableOperators.contains(selectedOperator) {
                                selectedOperator = availableOperators.first ?? ""
                            }
                            // Reset value when field changes
                            filterValue = ""
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Operator")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Operator", selection: $selectedOperator) {
                            ForEach(availableOperators, id: \.self) { op in
                                Text(op).tag(op)
                            }
                        }
                        .frame(width: 150)
                        .disabled(selectedField.isEmpty)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Value")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let fieldType = fieldTypes[selectedField] {
                            switch fieldType {
                            case .text:
                                TextField("Enter text", text: $filterValue)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 200)
                            case .date:
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .frame(width: 200)
                                    .onChange(of: selectedDate) { oldValue, newValue in
                                        filterValue = dateFormatter.string(from: newValue)
                                    }
                            case .boolean:
                                Picker("", selection: $filterValue) {
                                    Text("Yes").tag("YES")
                                    Text("No").tag("NO")
                                }
                                .frame(width: 200)
                            }
                        } else {
                            TextField("Select a field first", text: .constant(""))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                                .disabled(true)
                        }
                    }
                }
                .padding(.bottom, 8)
                
                // Search Button
                Button(action: executeQuery) {
                    Text("Search")
                        .frame(width: 100)
                        .padding(.vertical, 6)
                        .background(selectedField.isEmpty || filterValue.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedField.isEmpty || filterValue.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Results Area
            VStack(alignment: .leading, spacing: 12) {
                Text("Results")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                if isLoading {
                    ProgressView("Loading results...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else if queryResults.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            switch selectedDataType {
                            case .ad:
                                if let results = queryResults as? [ADRecord] {
                                    ADResultsTableView(results: results)
                                }
                            case .hr:
                                if let results = queryResults as? [HRRecord] {
                                    HRResultsTableView(results: results)
                                }
                            case .combined:
                                if let results = queryResults as? [CombinedRecord] {
                                    CombinedResultsTableView(results: results)
                                }
                            case .packageStatus:
                                if let results = queryResults as? [PackageRecord] {
                                    PackageResultsTableView(results: results)
                                }
                            case .testing:
                                if let results = queryResults as? [TestRecord] {
                                    TestResultsTableView(results: results)
                                }
                            case .migration:
                                if let results = queryResults as? [MigrationRecord] {
                                    MigrationResultsTableView(results: results)
                                }
                            case .cluster:
                                if let results = queryResults as? [ClusterRecord] {
                                    ClusterResultsTableView(results: results)
                                }
                            }
                        }
                    }
                    
                    Text("\(queryResults.count) results found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func executeQuery() {
        guard !selectedField.isEmpty && !filterValue.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        queryResults = []
        
        Task {
            do {
                let results = try await DatabaseManager.shared.executeQuery(
                    dataType: selectedDataType,
                    field: selectedField,
                    operator: selectedOperator,
                    value: filterValue
                )
                
                await MainActor.run {
                    queryResults = results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// Results table views
struct ADResultsTableView: View {
    let results: [ADRecord]
    private let rowHeight: CGFloat = 18
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
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
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ForEach(results, id: \.id) { (record: ADRecord) in
                HStack(spacing: 0) {
                    Text(record.adGroup)
                        .frame(width: 300, alignment: .leading)
                    Text(record.systemAccount)
                        .frame(width: 200, alignment: .leading)
                    Text(record.applicationName)
                        .frame(width: 250, alignment: .leading)
                    Text(record.applicationSuite)
                        .frame(width: 200, alignment: .leading)
                    Text(record.otap)
                        .frame(width: 80, alignment: .leading)
                    Text(record.critical)
                        .frame(width: 80, alignment: .leading)
                }
                .frame(height: rowHeight)
                .font(.system(size: 11))
            }
        }
    }
}

struct HRResultsTableView: View {
    let results: [HRRecord]
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("System Account")
                    .frame(width: 200, alignment: .leading)
                Text("Department")
                    .frame(width: 200, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 200, alignment: .leading)
                Text("Job Role")
                    .frame(width: 200, alignment: .leading)
                Text("Division")
                    .frame(width: 200, alignment: .leading)
                Text("Leave Date")
                    .frame(width: 120, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ForEach(results, id: \.id) { (record: HRRecord) in
                HStack(spacing: 0) {
                    Text(record.systemAccount)
                        .frame(width: 200, alignment: .leading)
                    Text(record.department ?? "N/A")
                        .frame(width: 200, alignment: .leading)
                    Text(record.departmentSimple ?? "N/A")
                        .frame(width: 200, alignment: .leading)
                    Text(record.jobRole ?? "N/A")
                        .frame(width: 200, alignment: .leading)
                    Text(record.division ?? "N/A")
                        .frame(width: 200, alignment: .leading)
                    Text(record.leaveDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                        .frame(width: 120, alignment: .leading)
                }
                .frame(height: rowHeight)
                .font(.system(size: 11))
            }
        }
    }
}

struct CombinedResultsTableView: View {
    let results: [CombinedRecord]
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Group {
                    Text("AD Group")
                        .frame(width: 250, alignment: .leading)
                    Text("System Account")
                        .frame(width: 200, alignment: .leading)
                    Text("Application")
                        .frame(width: 200, alignment: .leading)
                    Text("Suite")
                        .frame(width: 200, alignment: .leading)
                    Text("OTAP")
                        .frame(width: 100, alignment: .leading)
                    Text("Critical")
                        .frame(width: 100, alignment: .leading)
                }
                .background(Color.blue.opacity(0.1))
                
                Group {
                    Text("Department")
                        .frame(width: 200, alignment: .leading)
                    Text("Job Role")
                        .frame(width: 200, alignment: .leading)
                    Text("Division")
                        .frame(width: 200, alignment: .leading)
                    Text("Leave Date")
                        .frame(width: 120, alignment: .leading)
                }
                .background(Color.green.opacity(0.1))
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ForEach(results, id: \.id) { (record: CombinedRecord) in
                HStack(spacing: 0) {
                    Group {
                        Text(record.adGroup)
                            .frame(width: 250, alignment: .leading)
                        Text(record.systemAccount)
                            .frame(width: 200, alignment: .leading)
                        Text(record.applicationName)
                            .frame(width: 200, alignment: .leading)
                        Text(record.applicationSuite)
                            .frame(width: 200, alignment: .leading)
                        Text(record.otap)
                            .frame(width: 100, alignment: .leading)
                        Text(record.critical)
                            .frame(width: 100, alignment: .leading)
                    }
                    .background(Color.blue.opacity(0.05))
                    
                    Group {
                        Text(record.department ?? "N/A")
                            .frame(width: 200, alignment: .leading)
                        Text(record.jobRole ?? "N/A")
                            .frame(width: 200, alignment: .leading)
                        Text(record.division ?? "N/A")
                            .frame(width: 200, alignment: .leading)
                        Text(record.leaveDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                            .frame(width: 120, alignment: .leading)
                    }
                    .background(Color.green.opacity(0.05))
                }
                .frame(height: rowHeight)
                .font(.system(size: 11))
            }
        }
    }
}

struct PackageResultsTableView: View {
    let results: [PackageRecord]
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Application Name")
                    .frame(width: 200, alignment: .leading)
                Text("Package Status")
                    .frame(width: 150, alignment: .leading)
                Text("Readiness Date")
                    .frame(width: 120, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ForEach(results, id: \.id) { (record: PackageRecord) in
                HStack(spacing: 0) {
                    Text(record.applicationName)
                        .frame(width: 200, alignment: .leading)
                    Text(record.packageStatus)
                        .frame(width: 150, alignment: .leading)
                    Text(record.packageReadinessDate.map { dateFormatter.string(from: $0) } ?? "N/A")
                        .frame(width: 120, alignment: .leading)
                }
                .frame(height: rowHeight)
                .font(.system(size: 11))
            }
        }
    }
}

struct TestResultsTableView: View {
    let results: [TestRecord]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
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
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ForEach(results, id: \.id) { record in
                HStack(spacing: 0) {
                    Text(record.applicationName)
                        .frame(width: 200, alignment: .leading)
                    Text(record.testStatus)
                        .frame(width: 150, alignment: .leading)
                    Text(DateFormatter.hrDateFormatter.string(from: record.testDate))
                        .frame(width: 150, alignment: .leading)
                    Text(record.testResult)
                        .frame(width: 150, alignment: .leading)
                    Text(record.testComments ?? "")
                        .frame(width: 200, alignment: .leading)
                }
                .padding(.vertical, 4)
                .font(.system(size: 11))
            }
        }
    }
}

struct MigrationResultsTableView: View {
    let results: [MigrationRecord]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
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
            ForEach(results, id: \.id) { record in
                HStack(spacing: 0) {
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
                .padding(.vertical, 4)
                .font(.system(size: 11))
            }
        }
    }
}

struct ClusterResultsTableView: View {
    let results: [ClusterRecord]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Department")
                    .frame(width: 200, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 200, alignment: .leading)
                Text("Domain")
                    .frame(width: 200, alignment: .leading)
                Text("Migration Cluster")
                    .frame(width: 200, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.windowBackgroundColor))
            
            // Results
            ForEach(results, id: \.id) { record in
                HStack(spacing: 0) {
                    Text(record.department)
                        .frame(width: 200, alignment: .leading)
                    Text(record.departmentSimple)
                        .frame(width: 200, alignment: .leading)
                    Text(record.domain)
                        .frame(width: 200, alignment: .leading)
                    Text(record.migrationCluster)
                        .frame(width: 200, alignment: .leading)
                }
                .padding(.vertical, 4)
                .font(.system(size: 11))
            }
        }
    }
}

#Preview {
    QueryView()
} 