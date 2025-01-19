import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @EnvironmentObject private var loginManager: LoginManager
    
    private var sidebarContent: some View {
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
                NavigationLink(value: "checklist-app-user") {
                    Label("Checklist App User", systemImage: "checklist")
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
    }
    
    private struct DetailView: View {
        @ObservedObject var progress: ImportProgress
        @Binding var selectedItem: String?
        
        var body: some View {
            Group {
                if let item = selectedItem {
                    switch item {
                    case "import":
                        ImportView(dismiss: { selectedItem = nil })
                            .environmentObject(progress)
                    case "validation":
                        ValidationView(progress: progress, dismiss: { selectedItem = nil })
                    case "content":
                        DatabaseContentView(refresh: nil, dismiss: { selectedItem = nil })
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
                    case "checklist-app-user":
                        ChecklistAppUserView()
                    case "export":
                        ExportView()
                    case "admin":
                        AdminStuffView()
                    case "dbtest":
                        DatabaseMaintenanceView()
                    default:
                        EmptyStateView()
                    }
                } else {
                    EmptyStateView()
                }
            }
        }
    }
    
    private struct EmptyStateView: View {
        var body: some View {
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
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            DetailView(progress: progress, selectedItem: $selectedItem)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: progress.validRecords.count) { _, newValue in
            if newValue > 0 { selectedItem = "validation" }
        }
        .onChange(of: progress.validHRRecords.count) { _, newValue in
            if newValue > 0 { selectedItem = "validation" }
        }
        .onChange(of: progress.validPackageRecords.count) { _, newValue in
            if newValue > 0 { selectedItem = "validation" }
        }
        .onChange(of: progress.validMigrationRecords.count) { _, newValue in
            if newValue > 0 { selectedItem = "validation" }
        }
        .onChange(of: progress.validTestRecords.count) { _, newValue in
            if newValue > 0 { selectedItem = "validation" }
        }
        .onChange(of: progress.validClusterRecords.count) { _, newValue in
            if newValue > 0 { selectedItem = "validation" }
        }
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(DatabaseManager.shared)
        .environmentObject(LoginManager(isLoggedIn: .constant(true)))
} 