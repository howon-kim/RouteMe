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
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            container = try ModelContainer(for: schema, configurations: configuration)
            print("SwiftData container initialized successfully")
        } catch {
            // If migration fails, delete the old store and create a new one
            print("SwiftData initialization failed: \(error)")
            print("Error type: \(type(of: error))")
            print("This usually happens when the data model changes or there are permission issues.")
            print("Attempting to clear existing store and create fresh container...")
            
            // Clear any existing store files
            Self.clearSwiftDataStore()
            
            // Wait a moment for file system operations to complete
            Thread.sleep(forTimeInterval: 0.5)
            
            do {
                let schema = Schema([Route.self])
                let configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .none,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: schema, configurations: configuration)
                print("Successfully created new SwiftData container after cleanup")
            } catch {
                print("Critical error: Failed to configure SwiftData container after cleanup: \(error)")
                print("Falling back to in-memory only container...")
                
                // Last resort: use in-memory container
                do {
                    let schema = Schema([Route.self])
                    let configuration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                    container = try ModelContainer(for: schema, configurations: configuration)
                    print("Using in-memory SwiftData container (data won't persist)")
                } catch {
                    fatalError("Critical failure: Cannot initialize SwiftData at all: \(error)")
                }
            }
        }
    }
    
    // Helper function to clear SwiftData store files
    private static func clearSwiftDataStore() {
        let fileManager = FileManager.default
        
        // Get all possible store locations
        let locations = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Application Support")
        ].compactMap { $0 }
        
        for storeURL in locations {
            // Try both bundle identifier and app name
            let possiblePaths = [
                Bundle.main.bundleIdentifier ?? "RouteMe",
                "RouteMe",
                "default.store"
            ]
            
            for path in possiblePaths {
                let appStoreURL = storeURL.appendingPathComponent(path)
                
                do {
                    if fileManager.fileExists(atPath: appStoreURL.path) {
                        // If it's a directory, clear SwiftData files inside
                        var isDirectory: ObjCBool = false
                        fileManager.fileExists(atPath: appStoreURL.path, isDirectory: &isDirectory)
                        
                        if isDirectory.boolValue {
                            let files = try fileManager.contentsOfDirectory(at: appStoreURL, includingPropertiesForKeys: nil)
                            for file in files {
                                if file.pathExtension == "store" || 
                                   file.lastPathComponent.contains("default") ||
                                   file.pathExtension == "store-wal" ||
                                   file.pathExtension == "store-shm" {
                                    try fileManager.removeItem(at: file)
                                    print("Removed SwiftData file: \(file.lastPathComponent)")
                                }
                            }
                        } else if appStoreURL.lastPathComponent.contains("store") {
                            // Remove individual store file
                            try fileManager.removeItem(at: appStoreURL)
                            print("Removed SwiftData file: \(appStoreURL.lastPathComponent)")
                        }
                    }
                } catch {
                    print("Error clearing SwiftData store at \(appStoreURL.path): \(error)")
                }
            }
            
            // Also try to remove the default.store file directly
            let defaultStore = storeURL.appendingPathComponent("default.store")
            if fileManager.fileExists(atPath: defaultStore.path) {
                try? fileManager.removeItem(at: defaultStore)
                print("Removed default.store file")
            }
        }
        
        print("SwiftData store cleanup completed")
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
