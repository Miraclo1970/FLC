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
                
                Section("Organisation Analysis") {
                    NavigationLink(value: "baseline-accounts") {
                        Label("Baseline Accounts", systemImage: "person.2.circle")
                    }
                    NavigationLink(value: "baseline-applications") {
                        Label("Baseline Applications", systemImage: "app.badge.checkmark")
                    }
                    NavigationLink(value: "baseline-applications-usage") {
                        Label("Baseline Applications Usage", systemImage: "chart.bar.xaxis")
                    }
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
                case "baseline-accounts":
                    BaselineAccountsView()
                case "baseline-applications":
                    BaselineApplicationsView()
                case "baseline-applications-usage":
                    BaselineApplicationsUsageView()
                case "department-progress":
                    DepartmentProgressView()
                case "division-progress":
                    DivisionProgressView()
                case "cluster-progress":
                    ClusterProgressView()
                case "organisation-progress":
                    OrganisationProgressView()
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