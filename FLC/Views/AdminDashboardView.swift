import SwiftUI

struct AdminDashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @State private var isEnglish = true
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar with fixed width
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
                
                NavigationLink(value: "reports") {
                    Label("Reports", systemImage: "chart.bar.doc.horizontal")
                }
                
                Divider()
                
                NavigationLink(value: "admin") {
                    Label("Admin", systemImage: "gear")
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
            .frame(minWidth: 200, maxWidth: 200)
            .listStyle(SidebarListStyle())
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
                case "reports":
                    Text("Reports")
                case "admin":
                    AdminStuffView()
                case "dbtest":
                    TestDataGeneratorView()
                default:
                    Text("Select an option from the sidebar")
                }
            } else {
                VStack {
                    Text("Select an option from the sidebar")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .navigationSplitViewStyle(.automatic)
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