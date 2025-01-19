import SwiftUI

struct EnvironmentSelectorView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var showingEnvironmentPicker = false
    @State private var selectedEnvironment: Environment?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSwitching = false
    
    var body: some View {
        Menu {
            ForEach(Environment.allCases, id: \.self) { env in
                Button(action: {
                    selectedEnvironment = env
                    isSwitching = true
                    Task {
                        do {
                            try await databaseManager.switchEnvironment(to: env)
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                        isSwitching = false
                    }
                }) {
                    HStack {
                        Text(env.rawValue)
                        if databaseManager.currentEnvironment == env {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(isSwitching)
            }
        } label: {
            HStack {
                if isSwitching {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Label(databaseManager.currentEnvironment.rawValue, systemImage: "globe")
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .disabled(isSwitching)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
} 