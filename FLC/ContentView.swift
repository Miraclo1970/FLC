//
//  ContentView.swift
//  FLC
//
//  Created by Mirko van Velden on 13/12/2024.
//

import SwiftUI

struct ContentView: View {
    @State private var showingAdminDashboard = true
    @State private var isEnglish = true
    
    var body: some View {
        Group {
            if showingAdminDashboard {
                AdminDashboardView(isEnglish: isEnglish)
            } else {
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
                        
                        // Login View centered in the window
                        LoginView(showingAdminDashboard: $showingAdminDashboard, isEnglish: isEnglish)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        Spacer()
                    }
                }
                .frame(minWidth: 600, minHeight: 400)
            }
        }
        .animation(.default, value: showingAdminDashboard)
    }
}

#Preview {
    ContentView()
}
