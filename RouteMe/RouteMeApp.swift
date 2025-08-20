//
//  RouteMeApp.swift
//  RouteMe
//
//  Created by Howon Kim on 8/5/25.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct RouteMeApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([Route.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // If migration fails, delete the old store and create a new one
            print("SwiftData schema migration failed: \(error)")
            print("This usually happens when the data model changes.")
            print("Creating fresh container (existing routes will be lost)...")
            
            // Clear any existing store files
            Self.clearSwiftDataStore()
            
            do {
                let schema = Schema([Route.self])
                let configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
                container = try ModelContainer(for: schema, configurations: configuration)
                print("Successfully created new SwiftData container")
            } catch {
                fatalError("Failed to configure SwiftData container after cleanup: \(error)")
            }
        }
    }
    
    // Helper function to clear SwiftData store files
    private static func clearSwiftDataStore() {
        guard let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Could not find application support directory")
            return
        }
        
        let appStoreURL = storeURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "RouteMe")
        
        do {
            if FileManager.default.fileExists(atPath: appStoreURL.path) {
                let files = try FileManager.default.contentsOfDirectory(at: appStoreURL, includingPropertiesForKeys: nil)
                for file in files {
                    if file.pathExtension == "store" || file.lastPathComponent.contains("default") {
                        try FileManager.default.removeItem(at: file)
                        print("Removed SwiftData store file: \(file.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error clearing SwiftData store: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .onAppear {
                    // Initialize menu bar when the app appears
                    MenuBarManager.shared.setupMenuBar(with: container)
                }
        }
    }
}
