//
//  RoutesView.swift
//  RouteMe
//
//  Created by Howon Kim on 8/9/25.
//

import SwiftUI
import SwiftData

struct RoutesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var routes: [Route]
    @State private var showingAddRoute = false
    @State private var selectedRoute: Route?
    @State private var operationMessage: String = ""
    @State private var showingOperationAlert = false
    @StateObject private var helperToolManager = HelperToolManager()
    @State private var showingHelperInstallPrompt = false
    
    var activeRoutesCount: Int {
        routes.filter(\.isActive).count
    }
    
    var needsHelperTool: Bool {
        helperToolManager.status != "Registered"
    }
    
    var routesByInterface: [String: [Route]] {
        Dictionary(grouping: routes) { $0.interface }
    }
    
    var sortedInterfaces: [String] {
        routesByInterface.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Routes")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
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
                            Menu {
                                Button(action: {
                                    Task {
                                        await applyAllRoutesToSystem()
                                    }
                                }) {
                                    Label("Apply All Routes", systemImage: "plus.circle")
                                }
                                .disabled(routes.isEmpty || routes.allSatisfy(\.isActive))
                                
                                Button(action: {
                                    Task {
                                        await removeAllRoutesFromSystem()
                                    }
                                }) {
                                    Label("Remove All Routes", systemImage: "minus.circle")
                                }
                                .disabled(routes.isEmpty || !routes.contains(where: \.isActive))
                                
                                Divider()
                                
                                Button(action: {
                                    Task {
                                        await refreshRouteStatuses()
                                    }
                                }) {
                                    Label("Refresh All Status", systemImage: "arrow.clockwise")
                                }
                                .disabled(routes.isEmpty)
                            } label: {
                                Label("Batch Actions", systemImage: "ellipsis.circle")
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
                                
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(.blue.gradient)
                            }
                            
                            VStack(spacing: 12) {
                                Text("No Custom Routes")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Create your first route to manage network traffic efficiently")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    showingAddRoute = true
                                }) {
                                    Label("Create Your First Route", systemImage: "plus.circle.fill")
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
                    // Interface-grouped Layout
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(sortedInterfaces, id: \.self) { interface in
                                let interfaceRoutes = routesByInterface[interface] ?? []
                                let activeCount = interfaceRoutes.filter(\.isActive).count
                                
                                VStack(spacing: 12) {
                                    // Interface Header
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: "wifi")
                                                .font(.headline)
                                                .foregroundStyle(.blue)
                                            
                                            Text(interface)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 12) {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(.green)
                                                    .frame(width: 6, height: 6)
                                                Text("\(activeCount) Active")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Text("\(interfaceRoutes.count) Total")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    // Routes for this interface
                                    LazyVStack(spacing: 12) {
                                        ForEach(interfaceRoutes, id: \.id) { route in
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
                                }
                            }
                        }
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
        .onChange(of: routes.count) { _, newCount in
            MenuBarManager.shared.updateRouteCount(newCount)
        }
        .onAppear {
            MenuBarManager.shared.updateRouteCount(routes.count)
            // Automatically refresh status when view appears
            Task {
                await refreshRouteStatuses()
            }
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
    
    private func deleteRoute(_ route: Route) {
        Task {
            // First remove from system if it's active
            if route.isActive {
                await route.removeFromSystem(using: helperToolManager)
            }
            
            // Then delete from model
            await MainActor.run {
                modelContext.delete(route)
                
                // Refresh menu bar
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
        
        // Refresh menu bar
        MenuBarManager.shared.updateRouteCount(0)
    }
    
    // MARK: - Route System Operations
    
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
        
        // Refresh the route status after applying
        await route.refreshSystemStatus(using: helperToolManager)
        
        // Refresh menu bar
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
        
        // Refresh the route status after removing
        await route.refreshSystemStatus(using: helperToolManager)
        
        // Refresh menu bar
        MenuBarManager.shared.updateRouteCount(routes.count)
    }
    
    private func applyAllRoutesToSystem() async {
        // Check if helper tool is installed
        guard !needsHelperTool else {
            await MainActor.run {
                showingHelperInstallPrompt = true
            }
            return
        }
        
        let results = await RouteManager.shared.applyRoutes(routes, using: helperToolManager)
        
        let successCount = results.filter(\.success).count
        let failureCount = results.count - successCount
        
        // Update active status based on results
        await MainActor.run {
            for result in results {
                result.route.isActive = result.success
                result.route.updatedAt = Date()
            }
            
            if failureCount == 0 {
                operationMessage = "Successfully applied \(successCount) route(s) to system"
            } else {
                operationMessage = "Applied \(successCount) route(s), failed: \(failureCount)"
            }
            showingOperationAlert = true
        }
    }
    
    private func removeAllRoutesFromSystem() async {
        // Check if helper tool is installed
        guard !needsHelperTool else {
            await MainActor.run {
                showingHelperInstallPrompt = true
            }
            return
        }
        
        let results = await RouteManager.shared.removeRoutes(routes, using: helperToolManager)
        
        let successCount = results.filter(\.success).count
        let failureCount = results.count - successCount
        
        // Update active status based on results
        await MainActor.run {
            for result in results {
                if result.success {
                    result.route.isActive = false // Successfully removed from system
                    result.route.updatedAt = Date()
                }
            }
            
            if failureCount == 0 {
                operationMessage = "Successfully removed \(successCount) route(s) from system"
            } else {
                operationMessage = "Removed \(successCount) route(s), failed: \(failureCount)"
            }
            showingOperationAlert = true
        }
    }
    
    private func refreshRouteStatuses() async {
        // Check actual system status for all routes
        let statusMap = await RouteManager.shared.checkRoutesStatus(routes, using: helperToolManager)
        
        // Update each route's active status
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
        
        // Refresh menu bar
        MenuBarManager.shared.updateRouteCount(routes.count)
    }
}

// MARK: - RouteCard Component

struct RouteCard: View {
    let route: Route
    let helperToolManager: HelperToolManager
    let onEdit: () -> Void
    let onApply: () -> Void
    let onRemove: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with route name, status, and actions
            HStack(spacing: 12) {
                // Route Name
                Text(route.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(route.isActive ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(route.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(route.isActive ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(route.isActive ? .green.opacity(0.1) : .red.opacity(0.1))
                )
                
                // Edit and Delete buttons
                HStack(spacing: 8) {
                    // Edit Button
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("Edit")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.regularMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Delete Button
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("Delete")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.regularMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Details Row
            HStack(spacing: 16) {
                DetailItem(title: "IP Address", value: route.ipAddress, icon: "network")
                DetailItem(title: "Gateway", value: route.gateway, icon: "point.topleft.down.curvedto.point.bottomright.up")
                DetailItem(title: "Subnet Mask", value: route.subnetMask, icon: "rectangle.3.group")
                DetailItem(title: "Interface", value: route.interface, icon: "wifi")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Action Buttons
            HStack(spacing: 8) {
                // Apply Button
                Button(action: onApply) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Apply")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(route.isActive ? .secondary : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(route.isActive ? AnyShapeStyle(Color.gray.opacity(0.2)) : AnyShapeStyle(Color.green.gradient))
                    )
                }
                .disabled(route.isActive)
                .buttonStyle(.plain)
                
                // Remove Button
                Button(action: onRemove) {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle.fill")
                        Text("Remove")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(!route.isActive ? .secondary : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(!route.isActive ? AnyShapeStyle(Color.gray.opacity(0.2)) : AnyShapeStyle(Color.red.gradient))
                    )
                }
                .disabled(!route.isActive)
                .buttonStyle(.plain)
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
            Button("Edit Route") {
                onEdit()
            }
            
            Button("Duplicate Route") {
                onDuplicate()
            }
            
            Divider()
            
            Button("Delete Route", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct DetailItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
    }
}

struct AddEditRouteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let route: Route?
    
    @State private var name: String
    @State private var ipAddress: String
    @State private var subnetMask: String
    @State private var cidrNotation: String
    @State private var gateway: String
    @State private var interface: String
    @State private var isDetectingGateway: Bool = false
    @State private var activeNetworkPorts: [NetworkPort] = []
    @StateObject private var helperToolManager = HelperToolManager()
    
    // Auto-detection state
    @State private var isAutoDetectedSubnet: Bool = false
    
    init(route: Route? = nil) {
        self.route = route
        _name = State(initialValue: route?.name ?? "")
        _ipAddress = State(initialValue: route?.ipAddress ?? "")
        let initialSubnetMask = route?.subnetMask ?? "255.255.255.0"
        _subnetMask = State(initialValue: initialSubnetMask)
        _cidrNotation = State(initialValue: Self.subnetMaskToCIDRString(initialSubnetMask))
        _gateway = State(initialValue: route?.gateway ?? "")
        _interface = State(initialValue: route?.interface ?? "")
    }
    
    var isEditing: Bool {
        route != nil
    }
    
    var isFormValid: Bool {
        !name.isEmpty &&
        Route.isValidIPAddress(ipAddress) &&
        Route.isValidIPAddress(subnetMask) &&
        Route.isValidIPAddress(gateway) &&
        !interface.isEmpty
    }
    
    var formValidationMessage: String? {
        if name.isEmpty {
            return "Route name is required"
        }
        if !Route.isValidIPAddress(ipAddress) {
            return "Please enter a valid IP address"
        }
        if !Route.isValidIPAddress(subnetMask) {
            return "Please enter a valid subnet mask"
        }
        if !Route.isValidIPAddress(gateway) {
            return "Please enter a valid gateway address"
        }
        if interface.isEmpty {
            return "Please select a network interface"
        }
        return nil
    }
    
    // Auto-detect subnet mask based on IP address
    private func detectSubnetMask(from ipAddress: String) -> String {
        let components = ipAddress.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return "255.255.255.255" }
        
        // Simple rule: if IP octet is 0, subnet octet is 0; if IP octet is not 0, subnet octet is 255
        let subnetComponents = components.map { $0 == 0 ? "0" : "255" }
        return subnetComponents.joined(separator: ".")
    }
    
    // Convert subnet mask to CIDR string
    static func subnetMaskToCIDRString(_ subnetMask: String) -> String {
        let components = subnetMask.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return "/32" }
        
        var cidr = 0
        for component in components {
            cidr += component.nonzeroBitCount
        }
        
        return "/\(cidr)"
    }
    
    // Convert CIDR to subnet mask
    private func cidrToSubnetMask(_ cidr: String) -> String {
        let cidrNumber = Int(cidr.dropFirst()) ?? 32 // Remove '/' and convert
        let mask = (0xFFFFFFFF << (32 - cidrNumber)) & 0xFFFFFFFF
        
        let octet1 = (mask >> 24) & 0xFF
        let octet2 = (mask >> 16) & 0xFF
        let octet3 = (mask >> 8) & 0xFF
        let octet4 = mask & 0xFF
        
        return "\(octet1).\(octet2).\(octet3).\(octet4)"
    }
    
    private func updateSubnetMask() {
        let newSubnetMask = detectSubnetMask(from: ipAddress)
        let components = ipAddress.split(separator: ".").compactMap { Int($0) }
        
        // Check if any octet is 0 and IP is valid
        let hasZeroOctet = components.contains(0)
        
        if hasZeroOctet && Route.isValidIPAddress(ipAddress) && components.count == 4 {
            subnetMask = newSubnetMask
            cidrNotation = Self.subnetMaskToCIDRString(newSubnetMask)
            isAutoDetectedSubnet = true
        } else {
            isAutoDetectedSubnet = false
            if subnetMask.isEmpty || isAutoDetectedSubnet {
                subnetMask = "255.255.255.255" // Default when no zeros
                cidrNotation = Self.subnetMaskToCIDRString("255.255.255.255")
            }
        }
    }
    
    private func updateCIDRFromInput() {
        // Update subnet mask when CIDR is manually changed
        subnetMask = cidrToSubnetMask(cidrNotation)
        isAutoDetectedSubnet = false
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        
                        Text(isEditing ? "Edit Route" : "Create New Route")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Configure network routing parameters")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Route Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Route Information")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Route Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                TextField("Enter a descriptive name", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("IP Address")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                TextField("192.168.1.0", text: $ipAddress)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: ipAddress) { oldValue, newValue in
                                        updateSubnetMask()
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Network CIDR")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    
                                    if isAutoDetectedSubnet {
                                        HStack(spacing: 4) {
                                            Image(systemName: "wand.and.stars.inverse")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                            Text("Auto-detected")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                
                                HStack {
                                    if isAutoDetectedSubnet {
                                        Text(cidrNotation)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(.blue, lineWidth: 1)
                                            )
                                    } else {
                                        TextField("/24", text: $cidrNotation)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                            .onChange(of: cidrNotation) { oldValue, newValue in
                                                // Ensure it starts with '/'
                                                if !newValue.hasPrefix("/") && !newValue.isEmpty {
                                                    cidrNotation = "/\(newValue)"
                                                }
                                                updateCIDRFromInput()
                                            }
                                    }
                                    
                                    Spacer()
                                }
                                
                                if isAutoDetectedSubnet {
                                    Text("Zero octets detected - CIDR automatically calculated (0→0, non-zero→255)")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("Enter CIDR notation (e.g., /24 for 255.255.255.0)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Network Interface")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                VStack(alignment: .leading, spacing: 8) {
                                    Picker("Select Interface", selection: $interface) {
                                        Text("Choose network interface").tag("")
                                        ForEach(activeNetworkPorts, id: \.device) { port in
                                            Text(port.displayName).tag(port.device)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .disabled(activeNetworkPorts.isEmpty)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .onChange(of: interface) { oldValue, newValue in
                                        if !newValue.isEmpty && newValue != oldValue {
                                            Task {
                                                await MainActor.run {
                                                    isDetectingGateway = true
                                                }
                                                
                                                let networkManager = NetworkManager()
                                                if let detectedGateway = await networkManager.getGatewayForInterface(newValue, using: helperToolManager) {
                                                    await MainActor.run {
                                                        gateway = detectedGateway
                                                        isDetectingGateway = false
                                                    }
                                                } else {
                                                    await MainActor.run {
                                                        isDetectingGateway = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            let networkManager = NetworkManager()
                                            activeNetworkPorts = await networkManager.getActiveNetworkPorts(using: helperToolManager)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Refresh Interfaces")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Gateway")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                HStack {
                                    TextField("192.168.1.1", text: $gateway)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        .disabled(isDetectingGateway)
                                    
                                    if isDetectingGateway {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Auto-detecting...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Validation Warning - only show when needed
                    if let validationMessage = formValidationMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            
                            Text(validationMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save Changes" : "Create Route") {
                        saveRoute()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                }
            }
        }
        .frame(width: 600, height: 650)
        .onAppear {
            Task {
                let networkManager = NetworkManager()
                activeNetworkPorts = await networkManager.getActiveNetworkPorts(using: helperToolManager)
            }
            // Trigger auto-detection for existing routes
            updateSubnetMask()
        }
    }
    
    private func saveRoute() {
        if let existingRoute = route {
            existingRoute.updateRoute(
                name: name,
                ipAddress: ipAddress,
                subnetMask: subnetMask,
                gateway: gateway,
                interface: interface
            )
        } else {
            let newRoute = Route(
                name: name,
                ipAddress: ipAddress,
                subnetMask: subnetMask,
                gateway: gateway,
                interface: interface
            )
            modelContext.insert(newRoute)
        }
        
        // Refresh menu bar
        MenuBarManager.shared.updateRouteCount(0) // This triggers a menu refresh
        
        dismiss()
    }
}

extension Route {
    static func isValidIPAddress(_ ip: String) -> Bool {
        let ipRegex = #"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        return ip.range(of: ipRegex, options: .regularExpression) != nil
    }
}

#Preview {
    RoutesView()
        .modelContainer(for: Route.self, inMemory: true)
}
