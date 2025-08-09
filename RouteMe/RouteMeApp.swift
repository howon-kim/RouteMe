//
//  RouteMeApp.swift
//  RouteMe
//
//  Created by Howon Kim on 8/5/25.
//

import SwiftUI
import SwiftData

@main
struct RouteMeApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([Route.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to configure SwiftData container: \(error)")
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
