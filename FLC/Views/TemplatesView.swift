import SwiftUI

struct TemplatesView: View {
    @State private var isEnglish = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isEnglish ? "Download Templates" : "Download Sjablonen")
                .font(.title)
            
            DownloadButton(
                title: isEnglish ? "Download HR Template" : "Download HR Sjabloon",
                action: downloadHRTemplate
            )
            
            DownloadButton(
                title: isEnglish ? "Download AD Template" : "Download AD Sjabloon",
                action: downloadADTemplate
            )
            
            DownloadButton(
                title: isEnglish ? "Download Migration Template" : "Download Migratie Sjabloon",
                action: downloadMigrationTemplate
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func downloadHRTemplate() {
        // TODO: Implement HR template download
        print("Downloading HR template...")
    }
    
    private func downloadADTemplate() {
        // TODO: Implement AD template download
        print("Downloading AD template...")
    }
    
    private func downloadMigrationTemplate() {
        // TODO: Implement Migration template download
        print("Downloading Migration template...")
    }
}

struct DownloadButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.white)
                .frame(width: 200)
                .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? 
                      Color(red: 0.25, green: 0.35, blue: 0.45) :
                      Color(red: 0.2, green: 0.3, blue: 0.4))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    TemplatesView()
} 