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
            .navigationTitle("Helper tool is \(helperToolManager.status.lowercased())")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("Register") {
                        Task {
                            await helperToolManager.manageHelperTool(action: .install)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button("Unregister") {
                        Task {
                            await helperToolManager.manageHelperTool(action: .uninstall)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Network Hardware Ports")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await networkManager.refreshNetworkPorts(using: helperToolManager)
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .padding(4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(networkManager.isLoading)
            }
            
            if networkManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading network ports...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if networkManager.networkPorts.isEmpty {
                Text("No network ports found. Click Refresh to load network information.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Table(networkManager.networkPorts) {
                    TableColumn("Hardware Port") { port in
                        Text(port.hardwarePort)
                    }
                    TableColumn("Device") { port in
                        Text(port.device)
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn("Ethernet Address") { port in
                        Text(port.ethernetAddress)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    TableColumn("Status") { port in
                        HStack {
                            Circle()
                                .fill(port.isActive ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(port.statusText)
                                .font(.caption)
                                .foregroundStyle(port.isActive ? .green : .red)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding()
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
    @StateObject private var helperToolManager = HelperToolManager()
    
    var activeRoutesCount: Int {
        routes.filter(\.isActive).count
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
