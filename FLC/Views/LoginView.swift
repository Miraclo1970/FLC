import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userType: String?
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isEnglish = true
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            VStack {
                // Language Selection
                HStack(spacing: 20) {
                    Button(action: { isEnglish = true }) {
                        Text("🇬🇧 English")
                            .foregroundColor(isEnglish ? .blue : .gray)
                            .bold(isEnglish)
                    }
                    
                    Button(action: { isEnglish = false }) {
                        Text("🇳🇱 Nederlands")
                            .foregroundColor(!isEnglish ? .blue : .gray)
                            .bold(!isEnglish)
                    }
                }
                .padding()
                
                Spacer()
                
                // Login Form
                VStack(spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text(isEnglish ? "Login" : "Inloggen")
                        .font(.title)
                        .bold()
                    
                    VStack(spacing: 15) {
                        TextField(isEnglish ? "Username" : "Gebruikersnaam", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 250)
                        
                        SecureField(isEnglish ? "Password" : "Wachtwoord", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 250)
                    }
                    
                    Button(action: login) {
                        Text(isEnglish ? "Login" : "Inloggen")
                            .foregroundColor(.white)
                            .frame(width: 250, height: 40)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if showingError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(40)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 10)
                
                Spacer()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private func login() {
        let result = DatabaseManager.shared.validateUser(username: username, password: password)
        
        if result.success {
            userType = result.userType
            isLoggedIn = true
            showingError = false
        } else {
            errorMessage = isEnglish ? "Invalid username or password" : "Ongeldige gebruikersnaam of wachtwoord"
            showingError = true
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userType: .constant(nil))
} 