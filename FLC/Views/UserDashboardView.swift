import SwiftUI

struct UserDashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @State private var isEnglish = true
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar with fixed width
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
        } detail: {
            // Detail view
            ZStack {
                if let selectedItem {
                    switch selectedItem {
                    case "import":
                        ImportView()
                            .environmentObject(progress)
                    case "validation":
                        ValidationView(progress: progress)
                    case "content":
                        DatabaseContentView()
                    case "profile":
                        VStack(spacing: 20) {
                            Text(isEnglish ? "User Profile" : "Gebruikersprofiel")
                                .font(.largeTitle)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    default:
                        Text(isEnglish ? "Select an option from the sidebar" : "Selecteer een optie uit het menu")
                    }
                } else {
                    VStack {
                        Text(isEnglish ? "Select an option from the sidebar" : "Selecteer een optie uit het menu")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                }
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
    UserDashboardView(isLoggedIn: .constant(true))
} 