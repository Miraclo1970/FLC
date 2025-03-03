import SwiftUI

struct UserDashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @State private var isEnglish = true
    
    private var sidebarContent: some View {
        List(selection: $selectedItem) {
            NavigationLink(value: "import") {
                Label(isEnglish ? "Import" : "Importeren", 
                      systemImage: "square.and.arrow.down")
            }
            
            NavigationLink(value: "validation") {
                Label(isEnglish ? "Validation" : "Validatie", 
                      systemImage: "checkmark.shield")
            }
            
            NavigationLink(value: "content") {
                Label(isEnglish ? "Database Content" : "Database Inhoud", 
                      systemImage: "cylinder")
            }
            
            NavigationLink(value: "profile") {
                Label(isEnglish ? "Profile" : "Profiel", 
                      systemImage: "person.circle")
            }
            
            Divider()
            
            Button(action: {
                isLoggedIn = false
            }) {
                Label(isEnglish ? "Logout" : "Uitloggen", 
                      systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .frame(minWidth: 200, maxWidth: 200)
        .listStyle(SidebarListStyle())
    }
    
    private struct DetailView: View {
        @ObservedObject var progress: ImportProgress
        @Binding var selectedItem: String?
        let isEnglish: Bool
        
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
                    case "profile":
                        ProfileView(isEnglish: isEnglish)
                    default:
                        EmptyStateView(isEnglish: isEnglish)
                    }
                } else {
                    EmptyStateView(isEnglish: isEnglish)
                }
            }
        }
    }
    
    private struct ProfileView: View {
        let isEnglish: Bool
        
        var body: some View {
            VStack(spacing: 20) {
                Text(isEnglish ? "User Profile" : "Gebruikersprofiel")
                    .font(.largeTitle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
    
    private struct EmptyStateView: View {
        let isEnglish: Bool
        
        var body: some View {
            VStack {
                Text(isEnglish ? "Select an option from the sidebar" : "Selecteer een optie uit het menu")
                    .font(.title)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarContent
        } detail: {
            DetailView(progress: progress, selectedItem: $selectedItem, isEnglish: isEnglish)
        }
        .navigationSplitViewStyle(.automatic)
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
    UserDashboardView(isLoggedIn: .constant(true))
} 