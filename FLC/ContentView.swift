//
//  ContentView.swift
//  FLC
//
//  Created by Mirko van Velden on 13/12/2024.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var userType: String?
    
    var body: some View {
        if isLoggedIn {
            switch userType {
            case "admin":
                AdminDashboardView(isLoggedIn: $isLoggedIn)
            case "manager":
                ManagerDashboardView(isLoggedIn: $isLoggedIn)
            case "user":
                UserDashboardView(isLoggedIn: $isLoggedIn)
            default:
                Text("Invalid user type")
            }
        } else {
            LoginView(isLoggedIn: $isLoggedIn, userType: $userType)
        }
    }
}

#Preview {
    ContentView()
}
