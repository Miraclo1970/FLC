import SwiftUI

struct AdminDashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @State private var isEnglish = true
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                NavigationLink(value: "import") {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                
                NavigationLink(value: "validation") {
                    Label("Validation", systemImage: "checkmark.shield")
                }
                
                NavigationLink(value: "content") {
                    Label("Database", systemImage: "cylinder")
                }
                
                NavigationLink(value: "query") {
                    Label("Query", systemImage: "magnifyingglass")
                }
                
                Section("Analysis") {
                    NavigationLink(value: "department-progress") {
                        Label("Department Progress", systemImage: "building.2.fill")
                    }
                    
                    NavigationLink(value: "division-progress") {
                        Label("Division Progress", systemImage: "building.columns.fill")
                    }
                }
                
                Divider()
                
                NavigationLink(value: "admin") {
                    Label("Admin", systemImage: "gear")
                }
                
                NavigationLink(value: "export") {
                    Label("Export", systemImage: "square.and.arrow.down.on.square")
                }
                
                NavigationLink(value: "dbtest") {
                    Label("DB Test", systemImage: "hammer")
                }
                
                Divider()
                
                Button(action: {
                    isLoggedIn = false
                }) {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200)
        } detail: {
            // Detail view
            if let selectedItem {
                switch selectedItem {
                case "import":
                    ImportView()
                        .environmentObject(progress)
                case "validation":
                    ValidationView(progress: progress)
                case "content":
                    DatabaseContentView()
                case "query":
                    QueryView()
                case "department-progress":
                    DepartmentProgressView()
                case "division-progress":
                    DivisionProgressView()
                case "export":
                    ExportView()
                case "admin":
                    AdminStuffView()
                case "dbtest":
                    DatabaseMaintenanceView()
                default:
                    Text("Select an item from the sidebar")
                }
            } else {
                VStack {
                    Text("Select an item from the sidebar")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Image("falc_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400)
                        .opacity(0.1)
                )
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: progress.validRecords.count) { oldValue, newValue in
            if newValue > 0 {
                selectedItem = "validation"
            }
        }
        .onChange(of: progress.validHRRecords.count) { oldValue, newValue in
            if newValue > 0 {
                selectedItem = "validation"
            }
        }
        .onChange(of: progress.validPackageRecords.count) { oldValue, newValue in
            if newValue > 0 {
                selectedItem = "validation"
            }
        }
        .onChange(of: progress.validMigrationRecords.count) { oldValue, newValue in
            if newValue > 0 {
                selectedItem = "validation"
            }
        }
        .onChange(of: progress.validTestRecords.count) { oldValue, newValue in
            if newValue > 0 {
                selectedItem = "validation"
            }
        }
        .onChange(of: progress.validClusterRecords.count) { oldValue, newValue in
            if newValue > 0 {
                selectedItem = "validation"
            }
        }
    }
}

#Preview {
    AdminDashboardView(isLoggedIn: .constant(true))
} 