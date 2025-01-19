//
//  FLCApp.swift
//  FLC
//
//  Created by Mirko van Velden on 13/12/2024.
//

import SwiftUI

@main
struct FLCApp: App {
    init() {
        // Initialize database
        _ = DatabaseManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DatabaseManager.shared)
                .preferredColorScheme(.dark)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        EnvironmentSelectorView()
                            .environmentObject(DatabaseManager.shared)
                    }
                }
        }
    }
}
