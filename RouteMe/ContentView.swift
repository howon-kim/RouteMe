//
//  ContentView.swift
//  HelperToolApp
//
//  Created by Alin Lupascu on 2/25/25.
//

import SwiftUI
import SwiftData

enum SidebarItem: Hashable, Identifiable {
    case routes
    case networkPorts
    case interface(String)
    
    var id: String { 
        switch self {
        case .routes:
            return "routes"
        case .networkPorts:
            return "networkPorts"
        case .interface(let name):
            return "interface-\(name)"
        }
    }
    
    var displayName: String {
        switch self {
        case .routes:
            return "Routes"
        case .networkPorts:
            return "Network Ports"
        case .interface(let name):
            return name
        }
    }
    
    var icon: String {
        switch self {
        case .routes:
            return "point.3.connected.trianglepath.dotted"
        case .networkPorts:
            return "network"
        case .interface:
            return "wifi"
        }
    }
}

struct ContentView: View {
    @StateObject private var helperToolManager = HelperToolManager()
    @StateObject private var networkManager = NetworkManager()
    @Query private var routes: [Route]
    @State private var selectedSidebarItem: SidebarItem = .routes
    @State private var selectedInterface: String?
    
    var routesByInterface: [String: [Route]] {
        Dictionary(grouping: routes) { $0.interface }
    }
    
    var sortedInterfaces: [String] {
        routesByInterface.keys.sorted()
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSidebarItem) {
                // Routes Section
                Section {
                    NavigationLink(value: SidebarItem.routes) {
                        Label("All Routes", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    
                    // Interface subsections
                    ForEach(sortedInterfaces, id: \.self) { interface in
                        let interfaceRoutes = routesByInterface[interface] ?? []
                        let activeCount = interfaceRoutes.filter(\.isActive).count
                        
                        NavigationLink(value: SidebarItem.interface(interface)) {
                            HStack {
                                Label(interface, systemImage: "wifi")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(activeCount)")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                    Text("\(interfaceRoutes.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Routes")
                }
                
                // Network Ports Section
                Section {
                    NavigationLink(value: SidebarItem.networkPorts) {
                        Label("Network Ports", systemImage: "network")
                    }
                } header: {
                    Text("Network")
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            // Main content area
            Group {
                switch selectedSidebarItem {
                case .routes:
                    RoutesView()
                case .networkPorts:
                    NetworkPortsView(networkManager: networkManager, helperToolManager: helperToolManager)
                case .interface(let interfaceName):
                    InterfaceRoutesView(interface: interfaceName, routes: routesByInterface[interfaceName] ?? [])
                }
            }
            .navigationTitle("RouteMe")
            .toolbarBackground(.clear)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await helperToolManager.manageHelperTool()
            }
        }
    }
}

struct NetworkPortsView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var helperToolManager: HelperToolManager
    
    var activePortsCount: Int {
        networkManager.networkPorts.filter(\.isActive).count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Network Ports")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    Text("\(activePortsCount) Active")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                    Text("\(networkManager.networkPorts.count - activePortsCount) Inactive")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("•")
                                    .foregroundStyle(.secondary)
                                
                                Text("\(networkManager.networkPorts.count) Total Ports")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await networkManager.refreshNetworkPorts(using: helperToolManager)
                                }
                            }) {
                                Label(networkManager.isLoading ? "Refreshing..." : "Refresh Ports", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(networkManager.isLoading)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: Rectangle())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 0.5)
                }
                
                // Main Content
                if networkManager.isLoading {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 24) {
                            // Icon with loading animation
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(spacing: 12) {
                                Text("Loading Network Ports")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Scanning system network hardware...")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        
                        Spacer()
                    }
                } else if networkManager.networkPorts.isEmpty {
                    // Enhanced Empty State
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 24) {
                            // Icon with gradient background
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "network")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(.blue.gradient)
                            }
                            
                            VStack(spacing: 12) {
                                Text("No Network Ports Found")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Click refresh to scan for available network hardware ports")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    Task {
                                        await networkManager.refreshNetworkPorts(using: helperToolManager)
                                    }
                                }) {
                                    Label("Scan Network Ports", systemImage: "arrow.clockwise.circle.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .padding(.top, 8)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Network Ports List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(networkManager.networkPorts, id: \.id) { port in
                                NetworkPortCard(port: port)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
    }
}

// MARK: - NetworkPortCard Component

struct NetworkPortCard: View {
    let port: NetworkPort
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with port name and status
            HStack(spacing: 12) {
                // Port Name
                Text(port.hardwarePort)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(port.isActive ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(port.statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(port.isActive ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(port.isActive ? .green.opacity(0.1) : .red.opacity(0.1))
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Details Row
            HStack(spacing: 16) {
                DetailItem(title: "Device", value: port.device, icon: "desktopcomputer")
                DetailItem(title: "Ethernet Address", value: port.ethernetAddress, icon: "personalhotspot")
                DetailItem(title: "Connection", value: port.isActive ? "Connected" : "Disconnected", icon: port.isActive ? "wifi" : "wifi.slash")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
        .contextMenu {
            Button("Copy Device Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(port.device, forType: .string)
            }
            
            Button("Copy Ethernet Address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(port.ethernetAddress, forType: .string)
            }
        }
    }
}

struct InterfaceRoutesView: View {
    let interface: String
    let routes: [Route]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddRoute = false
    @State private var selectedRoute: Route?
    @State private var operationMessage: String = ""
    @State private var showingOperationAlert = false
    @State private var showingHelperInstallPrompt = false
    @StateObject private var helperToolManager = HelperToolManager()
    
    var activeRoutesCount: Int {
        routes.filter(\.isActive).count
    }
    
    var needsHelperTool: Bool {
        helperToolManager.status != "Registered"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                Text(interface)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    Text("\(activeRoutesCount) Active")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                    Text("\(routes.count - activeRoutesCount) Inactive")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("•")
                                    .foregroundStyle(.secondary)
                                
                                Text("\(routes.count) Total Routes")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await refreshRouteStatuses()
                                }
                            }) {
                                Label("Refresh Status", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(routes.isEmpty)
                            
                            Button(action: {
                                showingAddRoute = true
                            }) {
                                Label("Add Route", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: Rectangle())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 0.5)
                }
                
                // Main Content
                if routes.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "wifi")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(.blue.gradient)
                            }
                            
                            VStack(spacing: 12) {
                                Text("No Routes for \(interface)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Create routes specifically for the \(interface) interface")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    showingAddRoute = true
                                }) {
                                    Label("Add Route for \(interface)", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .padding(.top, 8)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Routes List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(routes, id: \.id) { route in
                                RouteCard(route: route, helperToolManager: helperToolManager) {
                                    selectedRoute = route
                                } onApply: {
                                    Task {
                                        await applyRouteToSystem(route)
                                    }
                                } onRemove: {
                                    Task {
                                        await removeRouteFromSystem(route)
                                    }
                                } onDelete: {
                                    deleteRoute(route)
                                } onDuplicate: {
                                    duplicateRoute(route)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRoute) {
            AddEditRouteView()
        }
        .sheet(item: $selectedRoute) { route in
            AddEditRouteView(route: route)
        }
        .alert("Route Operation", isPresented: $showingOperationAlert) {
            Button("OK") { }
        } message: {
            Text(operationMessage)
        }
        .alert("Helper Tool Required", isPresented: $showingHelperInstallPrompt) {
            Button("Install Helper Tool") {
                Task {
                    await helperToolManager.manageHelperTool(action: .install)
                }
            }
            .keyboardShortcut(.defaultAction)
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("RouteMe needs to install a helper tool to manage network routes. This requires administrator privileges and only needs to be done once.")
        }
    }
    
    // MARK: - Route Operations
    
    private func deleteRoute(_ route: Route) {
        Task {
            if route.isActive {
                await route.removeFromSystem(using: helperToolManager)
            }
            await MainActor.run {
                modelContext.delete(route)
                MenuBarManager.shared.updateRouteCount(0)
            }
        }
    }
    
    private func duplicateRoute(_ route: Route) {
        let duplicatedRoute = Route(
            name: "\(route.name) Copy",
            ipAddress: route.ipAddress,
            subnetMask: route.subnetMask,
            gateway: route.gateway,
            interface: route.interface
        )
        modelContext.insert(duplicatedRoute)
        MenuBarManager.shared.updateRouteCount(0)
    }
    
    private func applyRouteToSystem(_ route: Route) async {
        // Check if helper tool is installed
        guard !needsHelperTool else {
            await MainActor.run {
                showingHelperInstallPrompt = true
            }
            return
        }
        
        let result = await route.applyToSystem(using: helperToolManager)
        await MainActor.run {
            operationMessage = result.success ? 
                "Route '\(route.name)' applied successfully" : 
                "Failed to apply route '\(route.name)': \(result.message)"
            showingOperationAlert = true
        }
        
        await route.refreshSystemStatus(using: helperToolManager)
        MenuBarManager.shared.updateRouteCount(routes.count)
    }
    
    private func removeRouteFromSystem(_ route: Route) async {
        // Check if helper tool is installed
        guard !needsHelperTool else {
            await MainActor.run {
                showingHelperInstallPrompt = true
            }
            return
        }
        
        let result = await route.removeFromSystem(using: helperToolManager)
        await MainActor.run {
            operationMessage = result.success ? 
                "Route '\(route.name)' removed successfully" : 
                "Failed to remove route '\(route.name)': \(result.message)"
            showingOperationAlert = true
        }
        
        await route.refreshSystemStatus(using: helperToolManager)
        MenuBarManager.shared.updateRouteCount(routes.count)
    }
    
    private func refreshRouteStatuses() async {
        let statusMap = await RouteManager.shared.checkRoutesStatus(routes, using: helperToolManager)
        
        await MainActor.run {
            for route in routes {
                if let isActive = statusMap[route.id] {
                    route.isActive = isActive
                    route.updatedAt = Date()
                }
            }
        }
        
        let activeCount = statusMap.values.filter { $0 }.count
        
        // Status refreshed silently - no popup needed
        
        MenuBarManager.shared.updateRouteCount(routes.count)
    }
}
