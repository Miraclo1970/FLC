import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userType: String?
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isEnglish = true
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case username
        case password
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Language Selector
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.system(size: 28))
                    Picker("", selection: $isEnglish) {
                        Text("ENG").tag(true)
                        Text("NL").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            
            Image("falc_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .clipShape(Circle())
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 2)
                .padding(.bottom, 10)
            
            Text(isEnglish ? "Welcome to FALC" : "Welkom bij FALC")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.vertical, 20)
            
            VStack(spacing: 15) {
                TextField(isEnglish ? "Username" : "Gebruikersnaam", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .username)
                    .onSubmit {
                        focusedField = .password
                    }
                
                SecureField(isEnglish ? "Password" : "Wachtwoord", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        login()
                    }
                
                Button(action: login) {
                    Text(isEnglish ? "Login" : "Inloggen")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(username.isEmpty || password.isEmpty)
            }
            .frame(maxWidth: 300)
            .padding()
            
            if showError {
                Text(isEnglish ? "Invalid username or password" : "Ongeldige gebruikersnaam of wachtwoord")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            // Version information at the bottom
            Text("v0.93.6 (db: v4)")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            focusedField = .username
        }
    }
    
    private func login() {
        Task {
            do {
                let result = try await DatabaseManager.shared.validateUser(username: username, password: password)
                
                await MainActor.run {
                    if result.success {
                        userType = result.userType
                        isLoggedIn = true
                    } else {
                        errorMessage = isEnglish ? "Invalid username or password" : "Ongeldige gebruikersnaam of wachtwoord"
                        showError = true
                        password = ""  // Clear password field on error
                        focusedField = .password  // Focus back on password field
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = isEnglish ? "Login error: \(error.localizedDescription)" : "Inlogfout: \(error.localizedDescription)"
                    showError = true
                    password = ""  // Clear password field on error
                    focusedField = .password  // Focus back on password field
                }
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userType: .constant(nil))
} 