import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @EnvironmentObject private var loginManager: LoginManager
    
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
                
                Section("Organisation Analysis") {
                    NavigationLink(value: "department-progress") {
                        Label("Department Progress", systemImage: "building.2.fill")
                    }
                    NavigationLink(value: "division-progress") {
                        Label("Division Progress", systemImage: "chart.bar.doc.horizontal.fill")
                    }
                    NavigationLink(value: "cluster-progress") {
                        Label("Cluster Progress", systemImage: "square.grid.2x2.fill")
                    }
                    NavigationLink(value: "organisation-progress") {
                        Label("Organisation Progress", systemImage: "building.2.fill")
                    }
                }
                
                NavigationLink(value: "reports") {
                    Label("Reports", systemImage: "chart.bar.doc.horizontal")
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
                    loginManager.logout()
                }) {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200)
        } detail: {
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
                case "cluster-progress":
                    ClusterProgressView()
                case "organisation-progress":
                    OrganisationProgressView()
                case "reports":
                    ReportsView()
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

struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AdminDashboardView()
            .environmentObject(DatabaseManager.shared)
            .environmentObject(LoginManager(isLoggedIn: .constant(true)))
    }
} 