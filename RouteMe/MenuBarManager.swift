//
//  MenuBarManager.swift
//  RouteMe
//
//  Created by Howon Kim on 8/9/25.
//

import SwiftUI
import AppKit
import SwiftData
import Combine

class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var modelContainer: ModelContainer?
    private var routes: [Route] = []
    
    private override init() {
        super.init()
    }
    
    func setupMenuBar(with container: ModelContainer) {
        self.modelContainer = container
        setupMenuBar()
        loadRoutes()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "RouteMe")
        }
        
        updateMenu()
    }
    
    private func loadRoutes() {
        guard let modelContainer = modelContainer else { return }
        
        let context = modelContainer.mainContext
        let fetchDescriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.name)])
        
        do {
            routes = try context.fetch(fetchDescriptor)
            updateMenu()
        } catch {
            print("Failed to fetch routes: \(error)")
        }
    }
    
    private func updateMenu() {
        let menu = NSMenu()

        // Add routes
        if routes.isEmpty {
            let noRoutesItem = NSMenuItem()
            noRoutesItem.title = "No Routes"
            noRoutesItem.isEnabled = false
            menu.addItem(noRoutesItem)
        } else {
            for route in routes {
                let routeItem = NSMenuItem()
                routeItem.title = route.name
                
                // Create submenu for route details
                let submenu = NSMenu()
                
                // Status toggle
                let statusItem = NSMenuItem()
                statusItem.title = route.isEnabled ? "✅ Active" : "⭕ Inactive"
                statusItem.target = self
                statusItem.action = #selector(toggleRoute(_:))
                statusItem.representedObject = route.id
                submenu.addItem(statusItem)
                
                submenu.addItem(NSMenuItem.separator())
                
                // Route details
                let ipItem = NSMenuItem()
                ipItem.title = "IP: \(route.ipAddress)"
                ipItem.isEnabled = false
                submenu.addItem(ipItem)
                
                let maskItem = NSMenuItem()
                maskItem.title = "Mask: \(route.subnetMask)"
                maskItem.isEnabled = false
                submenu.addItem(maskItem)
                
                let gatewayItem = NSMenuItem()
                gatewayItem.title = "Gateway: \(route.gateway)"
                gatewayItem.isEnabled = false
                submenu.addItem(gatewayItem)
                
                let interfaceItem = NSMenuItem()
                interfaceItem.title = "Interface: \(route.interface)"
                interfaceItem.isEnabled = false
                submenu.addItem(interfaceItem)
                
                routeItem.submenu = submenu
                menu.addItem(routeItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add refresh item
        let refreshItem = NSMenuItem()
        refreshItem.title = "Refresh"
        refreshItem.target = self
        refreshItem.action = #selector(refreshRoutes)
        menu.addItem(refreshItem)
        
        // Add show main window item
        let showWindowItem = NSMenuItem()
        showWindowItem.title = "Show Main Window"
        showWindowItem.target = self
        showWindowItem.action = #selector(showMainWindow)
        menu.addItem(showWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add quit item
        let quitItem = NSMenuItem()
        quitItem.title = "Quit RouteMe"
        quitItem.target = self
        quitItem.action = #selector(quitApp)
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleRoute(_ sender: NSMenuItem) {
        guard let routeId = sender.representedObject as? UUID,
              let route = routes.first(where: { $0.id == routeId }),
              let modelContainer = modelContainer else { return }
        
        let context = modelContainer.mainContext
        route.isEnabled.toggle()
        route.updatedAt = Date()
        
        do {
            try context.save()
            loadRoutes() // Refresh the menu
        } catch {
            print("Failed to toggle route: \(error)")
        }
    }
    
    @objc private func refreshRoutes() {
        loadRoutes()
    }
    
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    func updateRouteCount(_ count: Int) {
        DispatchQueue.main.async {
            self.loadRoutes() // Refresh the entire menu when route count changes
        }
    }
    
    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
