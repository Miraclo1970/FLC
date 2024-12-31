import SwiftUI

struct AdminDashboardView: View {
    @State private var selectedTab = "Import"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .tag("Import")
            
            ValidationView()
                .tabItem {
                    Label("Validation", systemImage: "checkmark.circle")
                }
                .tag("Validation")
            
            QueryView()
                .tabItem {
                    Label("Query", systemImage: "magnifyingglass")
                }
                .tag("Query")
            
            ExportView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag("Export")
            
            AdminStuffView()
                .tabItem {
                    Label("Admin", systemImage: "gear")
                }
                .tag("Admin")
        }
        .padding()
    }
}

struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AdminDashboardView()
            .environmentObject(DatabaseManager.shared)
    }
} 