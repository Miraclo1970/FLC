import SwiftUI

@available(macOS 14.0, *)
struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
            Text(value)
                .font(.title)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    if #available(macOS 14.0, *) {
        DashboardCard(title: "Users", value: "42", icon: "person.2")
            .frame(width: 200)
    } else {
        Text("Only available on macOS 14.0 or newer")
    }
} 