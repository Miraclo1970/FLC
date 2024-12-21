import SwiftUI

struct AdminDashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @State private var isEnglish = true
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
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
                
                NavigationLink(value: "admin") {
                    Label("Admin Stuff", systemImage: "gear")
                }
                
                NavigationLink(value: "dbtest") {
                    Label("Database Test Panel", systemImage: "wrench.and.screwdriver")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            .navigationTitle("Admin Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar) {
                        Image(systemName: "sidebar.left")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        isLoggedIn = false
                    }) {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
        } detail: {
            NavigationStack {
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
        }
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
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

#Preview {
    AdminDashboardView(isLoggedIn: .constant(true))
} 