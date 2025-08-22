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

class MenuBarManager: NSObject, ObservableObject, NSMenuDelegate {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var modelContainer: ModelContainer?
    private var routes: [Route] = []
    private var helperToolManager = HelperToolManager()
    
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

        // Group routes by interface
        if routes.isEmpty {
            let noRoutesItem = NSMenuItem()
            noRoutesItem.title = "No Routes"
            noRoutesItem.isEnabled = false
            menu.addItem(noRoutesItem)
        } else {
            let routesByInterface = Dictionary(grouping: routes) { $0.interface }
            let sortedInterfaces = routesByInterface.keys.sorted()
            
            for interface in sortedInterfaces {
                let interfaceRoutes = routesByInterface[interface] ?? []
                
                // Interface item with submenu
                let interfaceItem = NSMenuItem()
                interfaceItem.title = "\(interface) (\(interfaceRoutes.count) routes)"
                
                let interfaceSubmenu = NSMenu()
                
                // Add "Apply All" option for this interface
                let applyAllItem = NSMenuItem()
                applyAllItem.title = "🚀 Apply All Routes"
                applyAllItem.target = self
                applyAllItem.action = #selector(applyAllRoutesForInterface(_:))
                applyAllItem.representedObject = interface
                interfaceSubmenu.addItem(applyAllItem)
                
                interfaceSubmenu.addItem(NSMenuItem.separator())
                
                // Add individual routes for this interface
                for route in interfaceRoutes.sorted(by: { $0.name < $1.name }) {
                    let routeItem = NSMenuItem()
                    // Show system status only
                    let systemIcon = route.isActive ? "✅" : "🔴"
                    routeItem.title = "\(systemIcon) \(route.name)"
                    
                    // Create submenu for route details and actions
                    let routeSubmenu = NSMenu()
                    
                    // Apply route to system
                    let applyItem = NSMenuItem()
                    applyItem.title = "🟢 Apply to System"
                    applyItem.target = self
                    applyItem.action = #selector(applyRouteToSystem(_:))
                    applyItem.representedObject = route.id
                    routeSubmenu.addItem(applyItem)
                    
                    // Remove route from system
                    let removeItem = NSMenuItem()
                    removeItem.title = "🔴 Remove from System"
                    removeItem.target = self
                    removeItem.action = #selector(removeRouteFromSystem(_:))
                    removeItem.representedObject = route.id
                    routeSubmenu.addItem(removeItem)
                    
                    // Check system status
                    let statusItem = NSMenuItem()
                    statusItem.title = "🔍 Check System Status"
                    statusItem.target = self
                    statusItem.action = #selector(checkRouteSystemStatus(_:))
                    statusItem.representedObject = route.id
                    routeSubmenu.addItem(statusItem)
                    
                    routeSubmenu.addItem(NSMenuItem.separator())
                    
                    // Route details
                    let detailsItem = NSMenuItem()
                    detailsItem.title = "📋 Route Details"
                    detailsItem.isEnabled = false
                    routeSubmenu.addItem(detailsItem)
                    
                    let ipItem = NSMenuItem()
                    ipItem.title = "   IP: \(route.ipAddress)"
                    ipItem.isEnabled = false
                    routeSubmenu.addItem(ipItem)
                    
                    let maskItem = NSMenuItem()
                    maskItem.title = "   Mask: \(route.subnetMask)"
                    maskItem.isEnabled = false
                    routeSubmenu.addItem(maskItem)
                    
                    let gatewayItem = NSMenuItem()
                    gatewayItem.title = "   Gateway: \(route.gateway)"
                    gatewayItem.isEnabled = false
                    routeSubmenu.addItem(gatewayItem)
                    
                    routeItem.submenu = routeSubmenu
                    interfaceSubmenu.addItem(routeItem)
                }
                
                interfaceItem.submenu = interfaceSubmenu
                menu.addItem(interfaceItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add route management items
        let addRouteItem = NSMenuItem()
        addRouteItem.title = "➕ Add New Route"
        addRouteItem.target = self
        addRouteItem.action = #selector(addNewRoute)
        menu.addItem(addRouteItem)
        
        // Add show main window item
        let showWindowItem = NSMenuItem()
        showWindowItem.title = "🪟 Show Main Window"
        showWindowItem.target = self
        showWindowItem.action = #selector(showMainWindow)
        menu.addItem(showWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add quit item
        let quitItem = NSMenuItem()
        quitItem.title = "❌ Quit RouteMe"
        quitItem.target = self
        quitItem.action = #selector(quitApp)
        menu.addItem(quitItem)
        
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    @objc private func applyRouteToSystem(_ sender: NSMenuItem) {
        guard let routeId = sender.representedObject as? UUID,
              let route = routes.first(where: { $0.id == routeId }),
              let modelContainer = modelContainer else { return }
        
        Task {
            let context = modelContainer.mainContext
            let result = await RouteManager.shared.addRoute(route, using: helperToolManager)
            
            await MainActor.run {
                route.isActive = result.success
                route.updatedAt = Date()
                
                showNotification(
                    title: result.success ? "Route Applied" : "Apply Failed",
                    message: result.success ? "Route '\(route.name)' applied to system" : "Failed to apply '\(route.name)': \(result.message)"
                )
            }
            
            do {
                try context.save()
                await MainActor.run {
                    loadRoutes() // Refresh the menu
                }
            } catch {
                print("Failed to save route changes: \(error)")
            }
        }
    }
    
    @objc private func removeRouteFromSystem(_ sender: NSMenuItem) {
        guard let routeId = sender.representedObject as? UUID,
              let route = routes.first(where: { $0.id == routeId }),
              let modelContainer = modelContainer else { return }
        
        Task {
            let context = modelContainer.mainContext
            let result = await RouteManager.shared.removeRoute(route, using: helperToolManager)
            
            await MainActor.run {
                if result.success {
                    route.isActive = false
                }
                route.updatedAt = Date()
                
                showNotification(
                    title: result.success ? "Route Removed" : "Remove Failed",
                    message: result.success ? "Route '\(route.name)' removed from system" : "Failed to remove '\(route.name)': \(result.message)"
                )
            }
            
            do {
                try context.save()
                await MainActor.run {
                    loadRoutes() // Refresh the menu
                }
            } catch {
                print("Failed to save route changes: \(error)")
            }
        }
    }
    
    
    @objc private func applyAllRoutesForInterface(_ sender: NSMenuItem) {
        guard let interface = sender.representedObject as? String else { return }
        
        let interfaceRoutes = routes.filter { $0.interface == interface }
        
        Task {
            let results = await RouteManager.shared.applyRoutes(interfaceRoutes, using: helperToolManager)
            let successCount = results.filter { $0.success }.count
            let totalCount = results.count
            
            // Update active status for all routes
            await MainActor.run {
                for result in results {
                    result.route.isActive = result.success
                    result.route.updatedAt = Date()
                }
                
                if successCount == totalCount {
                    showNotification(title: "Routes Applied", message: "Successfully applied all \(totalCount) routes for \(interface)")
                } else {
                    showNotification(title: "Partial Success", message: "Applied \(successCount)/\(totalCount) routes for \(interface)")
                }
            }
            
            // Save changes
            if let modelContainer = modelContainer {
                do {
                    try modelContainer.mainContext.save()
                    await MainActor.run {
                        loadRoutes() // Refresh the menu
                    }
                } catch {
                    print("Failed to save route statuses: \(error)")
                }
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func checkRouteSystemStatus(_ sender: NSMenuItem) {
        guard let routeId = sender.representedObject as? UUID,
              let route = routes.first(where: { $0.id == routeId }),
              let modelContainer = modelContainer else { return }
        
        Task {
            let context = modelContainer.mainContext
            let isActive = await RouteManager.shared.isRouteActive(route, using: helperToolManager)
            
            await MainActor.run {
                route.isActive = isActive
                route.updatedAt = Date()
                
                let statusText = isActive ? "ACTIVE" : "INACTIVE"
                let expectedGateway = route.gateway
                
                showNotification(
                    title: "Route Status Check", 
                    message: "Route '\(route.name)' is \(statusText)\nExpected gateway: \(expectedGateway)"
                )
            }
            
            do {
                try context.save()
                await MainActor.run {
                    loadRoutes() // Refresh the menu
                }
            } catch {
                print("Failed to save route status: \(error)")
            }
        }
    }
    
    @objc private func addNewRoute() {
        NSApp.activate(ignoringOtherApps: true)
        
        let addRouteWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 650),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        addRouteWindow.title = "Add New Route"
        addRouteWindow.center()
        addRouteWindow.isReleasedWhenClosed = false
        
        if let modelContainer = modelContainer {
            let addRouteView = AddEditRouteView()
                .modelContainer(modelContainer)
            // If you want AddEditRouteView to close the window, consider passing a closure or use a delegate/callback approach.
            // See SwiftUI documentation for custom dismiss handling when embedding in AppKit windows.
            addRouteWindow.contentView = NSHostingView(rootView: addRouteView)
        }
        
        addRouteWindow.makeKeyAndOrderFront(nil)
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
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Automatically refresh route statuses when menu opens
        Task {
            await checkAllRoutesStatusSilently()
        }
    }
    
    private func checkAllRoutesStatusSilently() async {
        guard let modelContainer = modelContainer else { return }
        
        let context = modelContainer.mainContext
        let statusMap = await RouteManager.shared.checkRoutesStatus(routes, using: helperToolManager)
        
        await MainActor.run {
            for route in routes {
                if let isActive = statusMap[route.id] {
                    route.isActive = isActive
                    route.updatedAt = Date()
                }
            }
        }
        
        do {
            try context.save()
            await MainActor.run {
                loadRoutes() // Refresh the menu with updated statuses
            }
        } catch {
            print("Failed to save route statuses: \(error)")
        }
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

