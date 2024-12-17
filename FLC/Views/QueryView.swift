import SwiftUI

@available(macOS 14.0, *)
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
    private enum FieldType {
        case text
        case date
        case boolean
    }
    
    // Field definitions with their types
    private let fieldTypes: [String: FieldType] = [
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
        "Employee Number": .text,
        "Leave Date": .date,
        
        // Package Status fields
        "Package Status": .text,
        "Package Readiness Date": .date,
        
        // Test fields
        "Test Status": .text,
        "Test Date": .date,
        "Test Result": .text,
        "Test Comments": .text,
        
        // Migration fields
        "New Application": .text,
        "Suite": .text,
        "New Suite": .text,
        "Scope Division": .text,
        "Department Simple": .text,
        "Migration Cluster": .text,
        "Migration Readiness": .text
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
            return ["System Account", "Department", "Job Role", "Division", "Employee Number", "Leave Date"]
        case .combined:
            return ["AD Group", "System Account", "Application Name", "Application Suite", "OTAP", "Critical",
                   "Department", "Job Role", "Division", "Employee Number", "Leave Date"]
        case .packageStatus:
            return ["System Account", "Application Name", "Package Status", "Package Readiness Date"]
        case .testing:
            return ["Application Name", "Test Status", "Test Date", "Test Result", "Test Comments"]
        case .migration:
            return ["AD Group", "Application Name", "New Application", "Suite", "New Suite", "Scope Division",
                   "Department Simple", "Migration Cluster", "Migration Readiness"]
        }
    }
    
    func executeQuery() async {
        guard !selectedField.isEmpty && !filterValue.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        queryResults = []
        
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
    
    var body: some View {
        QueryContentView(
            selectedDataType: $selectedDataType,
            selectedField: $selectedField,
            selectedOperator: $selectedOperator,
            filterValue: $filterValue,
            selectedDate: $selectedDate,
            isLoading: $isLoading,
            errorMessage: errorMessage,
            queryResults: queryResults,
            availableFields: availableFields,
            availableOperators: availableOperators,
            executeQuery: executeQuery
        )
    }
    
    // ... rest of the existing methods ...
}

@available(macOS 14.0, *)
private struct QueryContentView: View {
    @Binding var selectedDataType: ImportProgress.DataType
    @Binding var selectedField: String
    @Binding var selectedOperator: String
    @Binding var filterValue: String
    @Binding var selectedDate: Date
    @Binding var isLoading: Bool
    let errorMessage: String?
    let queryResults: [Any]
    let availableFields: [String]
    var availableOperators: [String]
    let executeQuery: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            DataTypeSelector(
                selectedDataType: $selectedDataType,
                selectedField: $selectedField,
                selectedOperator: $selectedOperator,
                filterValue: $filterValue,
                selectedDate: $selectedDate,
                queryResults: .constant([])
            )
            
            QueryBuilder(
                selectedField: $selectedField,
                selectedOperator: $selectedOperator,
                filterValue: $filterValue,
                selectedDate: $selectedDate,
                availableFields: availableFields,
                availableOperators: availableOperators
            )
            
            QueryResults(
                isLoading: isLoading,
                errorMessage: errorMessage,
                queryResults: queryResults,
                executeQuery: executeQuery
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(macOS 14.0, *)
private struct DataTypeSelector: View {
    @Binding var selectedDataType: ImportProgress.DataType
    @Binding var selectedField: String
    @Binding var selectedOperator: String
    @Binding var filterValue: String
    @Binding var selectedDate: Date
    @Binding var queryResults: [Any]
    
    var body: some View {
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
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .onChange(of: selectedDataType) { oldValue, newValue in
                selectedField = ""
                selectedOperator = "equals"
                filterValue = ""
                queryResults = []
            }
        }
        .padding(.horizontal)
    }
}

@available(macOS 14.0, *)
private struct QueryBuilder: View {
    @Binding var selectedField: String
    @Binding var selectedOperator: String
    @Binding var filterValue: String
    @Binding var selectedDate: Date
    let availableFields: [String]
    let availableOperators: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build Query")
                .font(.headline)
                .padding(.bottom, 4)
            
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
                }
                
                VStack(alignment: .leading) {
                    Text("Value")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if selectedOperator == "before" || selectedOperator == "after" {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                            .frame(width: 200)
                    } else {
                        TextField("Enter value", text: $filterValue)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

@available(macOS 14.0, *)
private struct QueryResults: View {
    let isLoading: Bool
    let errorMessage: String?
    let queryResults: [Any]
    let executeQuery: () async -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await executeQuery()
                    }
                }) {
                    Text("Execute Query")
                }
                .disabled(isLoading)
            }
            
            if isLoading {
                ProgressView("Executing query...")
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                ResultsList(results: queryResults)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

@available(macOS 14.0, *)
private struct ResultsList: View {
    let results: [Any]
    
    var body: some View {
        List {
            ForEach(0..<results.count, id: \.self) { index in
                Text(String(describing: results[index]))
            }
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    if #available(macOS 14.0, *) {
        QueryView()
    } else {
        Text("Only available on macOS 14.0 or newer")
    }
} 