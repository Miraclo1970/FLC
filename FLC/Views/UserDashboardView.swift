import SwiftUI

struct UserDashboardView: View {
    let isEnglish: Bool
    let username: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                NavigationLink(destination: Text("My Tasks")) {
                    Label(isEnglish ? "My Tasks" : "Mijn Taken", 
                          systemImage: "list.bullet")
                }
                NavigationLink(destination: Text("Messages")) {
                    Label(isEnglish ? "Messages" : "Berichten", 
                          systemImage: "envelope")
                }
                NavigationLink(destination: Text("Profile")) {
                    Label(isEnglish ? "Profile" : "Profiel", 
                          systemImage: "person.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            // Main Content
            VStack(spacing: 20) {
                Text(isEnglish ? "Welcome, \(username)" : "Welkom, \(username)")
                    .font(.largeTitle)
                    .padding(.top)
                
                // Quick Stats
                HStack(spacing: 20) {
                    DashboardCard(
                        title: isEnglish ? "My Tasks" : "Mijn Taken",
                        value: "3",
                        icon: "checkmark.circle"
                    )
                    DashboardCard(
                        title: isEnglish ? "Messages" : "Berichten",
                        value: "2",
                        icon: "envelope"
                    )
                }
                .padding()
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle(isEnglish ? "User Dashboard" : "Gebruiker Dashboard")
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
    UserDashboardView(isEnglish: true, username: "John")
} 