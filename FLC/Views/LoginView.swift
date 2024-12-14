import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var username = ""
    @State private var password = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @Binding var showingAdminDashboard: Bool
    @State private var showingManagerDashboard = false
    @State private var showingUserDashboard = false
    @State private var userType: String? = nil
    @FocusState private var focusedField: Field?
    let isEnglish: Bool
    
    enum Field {
        case username
        case password
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // User Input
            VStack(alignment: .leading, spacing: 8) {
                Text(isEnglish ? "User" : "Gebruiker")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                    TextField("", text: $username)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focusedField, equals: .username)
                        .onSubmit {
                            print("Username submitted: \(username)")
                            focusedField = .password
                        }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.textBackgroundColor))
                )
            }
            
            // Password Input
            VStack(alignment: .leading, spacing: 8) {
                Text(isEnglish ? "Password" : "Wachtwoord")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.secondary)
                    SecureField("", text: $password)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            print("Password submitted, attempting login...")
                            authenticateUser()
                        }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.textBackgroundColor))
                )
            }
            
            // Login Button
            Button(action: {
                print("Login button clicked, attempting login...")
                authenticateUser()
            }) {
                HStack {
                    Spacer()
                    Text(isEnglish ? "Login" : "Inloggen")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .alert(errorMessage, 
               isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            print("LoginView appeared")
            DatabaseManager.shared.ensureInitialData()
            focusedField = .username
        }
        .sheet(isPresented: $showingManagerDashboard) {
            ManagerDashboardView(isEnglish: isEnglish)
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showingUserDashboard) {
            UserDashboardView(isEnglish: isEnglish, username: username)
                .frame(minWidth: 800, minHeight: 600)
        }
    }
    
    private func authenticateUser() {
        print("Authenticating with username: \(username)")
        
        // Don't attempt login if fields are empty
        guard !username.isEmpty && !password.isEmpty else {
            print("Empty fields detected")
            errorMessage = isEnglish ? "Please fill in all fields" : "Vul alle velden in"
            showingError = true
            return
        }
        
        let result = DatabaseManager.shared.validateUser(username: username, password: password)
        print("Authentication result: \(result)")
        
        if result.success {
            print("Login successful, user type: \(result.userType ?? "unknown")")
            userType = result.userType
            switch result.userType {
            case "admin":
                print("Showing admin dashboard")
                DispatchQueue.main.async {
                    showingAdminDashboard = true
                }
            case "manager":
                print("Showing manager dashboard")
                showingManagerDashboard = true
            case "user":
                print("Showing user dashboard")
                showingUserDashboard = true
            default:
                print("Invalid user type")
                errorMessage = isEnglish ? "Invalid user type" : "Ongeldig gebruikerstype"
                showingError = true
            }
        } else {
            print("Login failed")
            errorMessage = isEnglish ? "Invalid Credentials" : "Ongeldige Gegevens"
            showingError = true
        }
    }
} 