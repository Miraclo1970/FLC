import SwiftUI

struct ManagerDashboardView: View {
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
                
                NavigationLink(value: "projects") {
                    Label(isEnglish ? "Project Management" : "Projectbeheer", 
                          systemImage: "list.bullet.clipboard")
                }
                
                NavigationLink(value: "team") {
                    Label(isEnglish ? "Team Overview" : "Team Overzicht", 
                          systemImage: "person.3")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            .navigationTitle(isEnglish ? "Manager Dashboard" : "Manager Dashboard")
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
                    case "projects":
                        VStack(spacing: 20) {
                            Text(isEnglish ? "Project Management" : "Projectbeheer")
                                .font(.largeTitle)
                                .padding(.top)
                            
                            DashboardCard(
                                title: isEnglish ? "Active Projects" : "Actieve Projecten",
                                value: "5",
                                icon: "folder"
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    case "team":
                        VStack(spacing: 20) {
                            Text(isEnglish ? "Team Overview" : "Team Overzicht")
                                .font(.largeTitle)
                                .padding(.top)
                            
                            DashboardCard(
                                title: isEnglish ? "Team Members" : "Teamleden",
                                value: "8",
                                icon: "person.2"
                            )
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
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

#Preview {
    ManagerDashboardView(isLoggedIn: .constant(true))
} 