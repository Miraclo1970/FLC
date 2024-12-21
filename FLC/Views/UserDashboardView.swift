import SwiftUI

struct UserDashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var progress = ImportProgress()
    @State private var selectedItem: String? = nil
    @State private var isEnglish = true
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
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
                
                NavigationLink(value: "tasks") {
                    Label(isEnglish ? "My Tasks" : "Mijn Taken", 
                          systemImage: "list.bullet")
                }
                
                NavigationLink(value: "messages") {
                    Label(isEnglish ? "Messages" : "Berichten", 
                          systemImage: "envelope")
                }
                
                NavigationLink(value: "profile") {
                    Label(isEnglish ? "Profile" : "Profiel", 
                          systemImage: "person.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            .navigationTitle(isEnglish ? "User Dashboard" : "Gebruiker Dashboard")
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
                        Label(isEnglish ? "Logout" : "Uitloggen", 
                              systemImage: "rectangle.portrait.and.arrow.right")
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
                    case "tasks":
                        VStack(spacing: 20) {
                            Text(isEnglish ? "My Tasks" : "Mijn Taken")
                                .font(.largeTitle)
                                .padding(.top)
                            
                            DashboardCard(
                                title: isEnglish ? "Active Tasks" : "Actieve Taken",
                                value: "3",
                                icon: "checkmark.circle"
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    case "messages":
                        VStack(spacing: 20) {
                            Text(isEnglish ? "Messages" : "Berichten")
                                .font(.largeTitle)
                                .padding(.top)
                            
                            DashboardCard(
                                title: isEnglish ? "Unread Messages" : "Ongelezen Berichten",
                                value: "2",
                                icon: "envelope"
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    case "profile":
                        VStack(spacing: 20) {
                            Text(isEnglish ? "Profile" : "Profiel")
                                .font(.largeTitle)
                                .padding(.top)
                            
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
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
    UserDashboardView(isLoggedIn: .constant(true))
} 