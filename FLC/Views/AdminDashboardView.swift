import SwiftUI

struct AdminDashboardView: View {
    let isEnglish: Bool
    @Environment(\.dismiss) var dismiss
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedItem) {
                NavigationLink(value: "templates") {
                    Label("Templates", systemImage: "doc")
                }
                
                NavigationLink(value: "import") {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                
                NavigationLink(value: "validation") {
                    Label("Validation", systemImage: "checkmark.shield")
                }
                
                NavigationLink(value: "history") {
                    Label("History", systemImage: "clock.arrow.2.circlepath")
                }
                
                NavigationLink(value: "content") {
                    Label("Database Content", systemImage: "cylinder")
                }
                
                NavigationLink(value: "combined") {
                    Label("Database Combined Data", systemImage: "square.stack")
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
                        dismiss()
                    }) {
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                }
            }
        } detail: {
            NavigationStack {
                if let selectedItem {
                    switch selectedItem {
                    case "templates":
                        TemplatesView(isEnglish: isEnglish)
                    case "import":
                        ImportView().environmentObject(progress)
                    case "validation":
                        ValidationView(progress: progress)
                    case "history":
                        Text("History")
                    case "content":
                        DatabaseContentView()
                    case "combined":
                        Text("Database Combined Data")
                    case "query":
                        Text("Query")
                    case "reports":
                        Text("Reports")
                    case "admin":
                        Text("Admin Stuff")
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
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

#Preview {
    AdminDashboardView(isEnglish: true)
} 