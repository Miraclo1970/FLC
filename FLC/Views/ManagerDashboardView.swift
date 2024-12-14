import SwiftUI

struct ManagerDashboardView: View {
    let isEnglish: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                NavigationLink(destination: Text("Project Management")) {
                    Label(isEnglish ? "Project Management" : "Projectbeheer", 
                          systemImage: "list.bullet.clipboard")
                }
                NavigationLink(destination: Text("Team Overview")) {
                    Label(isEnglish ? "Team Overview" : "Team Overzicht", 
                          systemImage: "person.3")
                }
                NavigationLink(destination: Text("Tasks")) {
                    Label(isEnglish ? "Tasks" : "Taken", 
                          systemImage: "checkmark.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            // Main Content
            VStack(spacing: 20) {
                Text(isEnglish ? "Manager Dashboard" : "Manager Dashboard")
                    .font(.largeTitle)
                    .padding(.top)
                
                // Quick Stats
                HStack(spacing: 20) {
                    DashboardCard(
                        title: isEnglish ? "Active Projects" : "Actieve Projecten",
                        value: "5",
                        icon: "folder"
                    )
                    DashboardCard(
                        title: isEnglish ? "Team Members" : "Teamleden",
                        value: "8",
                        icon: "person.2"
                    )
                }
                .padding()
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle(isEnglish ? "Manager Dashboard" : "Manager Dashboard")
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
                    Text(isEnglish ? "Logout" : "Uitloggen")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

#Preview {
    ManagerDashboardView(isEnglish: true)
} 