//
//  FLCApp.swift
//  FLC
//
//  Created by Mirko van Velden on 13/12/2024.
//

import SwiftUI

@available(macOS 14.0, *)
@main
struct FLCApp: App {
    init() {
        // Initialize database
        _ = DatabaseManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

