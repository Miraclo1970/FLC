import SwiftUI

struct TestDataGeneratorView: View {
    @State private var message: String = ""
    @State private var showingMessage = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Data Generator")
                .font(.title)
                .padding()
            
            Button(action: generateTestData) {
                Text("Generate Test Data Files")
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingMessage {
                Text(message)
                    .foregroundColor(message.contains("Error") ? .red : .green)
                    .padding()
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func generateTestData() {
        do {
            try TestDataGenerator.shared.saveTestDataToFiles()
            message = "Test data files generated successfully!\nCheck the Documents folder for ad_test_data.csv and hr_test_data.csv"
            showingMessage = true
        } catch {
            message = "Error generating test data: \(error.localizedDescription)"
            showingMessage = true
        }
    }
}

#Preview {
    TestDataGeneratorView()
} 