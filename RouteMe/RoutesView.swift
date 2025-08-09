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
    
    var body: some View {
        VStack {
            HStack {
                Text("Custom Routes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await applyAllRoutesToSystem()
                    }
                }) {
                    Label("Apply All", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .disabled(routes.filter(\.isEnabled).isEmpty)
                
                Button(action: {
                    Task {
                        await removeAllRoutesFromSystem()
                    }
                }) {
                    Label("Remove All", systemImage: "minus.circle")
                }
                .buttonStyle(.bordered)
                .disabled(routes.isEmpty)
                
                Button(action: {
                    showingAddRoute = true
                }) {
                    Label("Add Route", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            if routes.isEmpty {
                ContentUnavailableView(
                    "No Routes",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Add your first custom route to get started")
                )
            } else {
                Table(routes) {
                    TableColumn("Name") { route in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.name)
                                .font(.headline)
                            Text(route.displayDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    TableColumn("IP Address") { route in
                        Text(route.ipAddress)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    TableColumn("Subnet Mask") { route in
                        Text(route.subnetMask)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    TableColumn("Gateway") { route in
                        Text(route.gateway)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    TableColumn("Interface") { route in
                        Text(route.interface)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    TableColumn("Status") { route in
                        HStack {
                            Circle()
                                .fill(route.isEnabled ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Text(route.isEnabled ? "Active" : "Inactive")
                                .font(.caption)
                        }
                    }
                    
                    TableColumn("Actions") { route in
                        HStack(spacing: 8) {
                            Button(action: {
                                route.isEnabled.toggle()
                                route.updatedAt = Date()
                            }) {
                                Image(systemName: route.isEnabled ? "pause.circle" : "play.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Toggle route enable/disable")
                            
                            Button(action: {
                                Task {
                                    await applyRouteToSystem(route)
                                }
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                            .help("Apply route to system")
                            .disabled(!route.isEnabled)
                            
                            Button(action: {
                                Task {
                                    await removeRouteFromSystem(route)
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Remove route from system")
                            
                            Button(action: {
                                selectedRoute = route
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .help("Edit route")
                            
                            Button(action: {
                                deleteRoute(route)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete route")
                        }
                    }
                }
                .contextMenu(forSelectionType: Route.ID.self) { selection in
                    if selection.count == 1,
                       let routeId = selection.first,
                       let route = routes.first(where: { $0.id == routeId }) {
                        Button("Edit") {
                            selectedRoute = route
                        }
                        Button("Toggle Status") {
                            route.isEnabled.toggle()
                            route.updatedAt = Date()
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteRoute(route)
                        }
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
        }
        .alert("Route Operation", isPresented: $showingOperationAlert) {
            Button("OK") { }
        } message: {
            Text(operationMessage)
        }
    }
    
    private func deleteRoute(_ route: Route) {
        modelContext.delete(route)
    }
    
    // MARK: - Route System Operations
    
    private func applyRouteToSystem(_ route: Route) async {
        let result = await route.applyToSystem(using: helperToolManager)
        await MainActor.run {
            operationMessage = result.success ? 
                "Route '\(route.name)' applied successfully" : 
                "Failed to apply route '\(route.name)': \(result.message)"
            showingOperationAlert = true
        }
    }
    
    private func removeRouteFromSystem(_ route: Route) async {
        let result = await route.removeFromSystem(using: helperToolManager)
        await MainActor.run {
            operationMessage = result.success ? 
                "Route '\(route.name)' removed successfully" : 
                "Failed to remove route '\(route.name)': \(result.message)"
            showingOperationAlert = true
        }
    }
    
    private func applyAllRoutesToSystem() async {
        let enabledRoutes = routes.filter(\.isEnabled)
        let results = await RouteManager.shared.applyRoutes(enabledRoutes, using: helperToolManager)
        
        let successCount = results.filter(\.success).count
        let failureCount = results.count - successCount
        
        await MainActor.run {
            if failureCount == 0 {
                operationMessage = "Successfully applied \(successCount) route(s) to system"
            } else {
                operationMessage = "Applied \(successCount) route(s), failed: \(failureCount)"
            }
            showingOperationAlert = true
        }
    }
    
    private func removeAllRoutesFromSystem() async {
        let results = await RouteManager.shared.removeRoutes(routes, using: helperToolManager)
        
        let successCount = results.filter(\.success).count
        let failureCount = results.count - successCount
        
        await MainActor.run {
            if failureCount == 0 {
                operationMessage = "Successfully removed \(successCount) route(s) from system"
            } else {
                operationMessage = "Removed \(successCount) route(s), failed: \(failureCount)"
            }
            showingOperationAlert = true
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
    @State private var gateway: String
    @State private var interface: String
    @State private var isEnabled: Bool
    @State private var isDetectingGateway: Bool = false
    @State private var activeNetworkPorts: [NetworkPort] = []
    @StateObject private var helperToolManager = HelperToolManager()
    
    init(route: Route? = nil) {
        self.route = route
        _name = State(initialValue: route?.name ?? "")
        _ipAddress = State(initialValue: route?.ipAddress ?? "")
        _subnetMask = State(initialValue: route?.subnetMask ?? "")
        _gateway = State(initialValue: route?.gateway ?? "")
        _interface = State(initialValue: route?.interface ?? "")
        _isEnabled = State(initialValue: route?.isEnabled ?? true)
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Route Information") {
                    TextField("Name", text: $name)
                    TextField("IP Address", text: $ipAddress)
                        .font(.system(.body, design: .monospaced))
                    TextField("Subnet Mask", text: $subnetMask)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        TextField("Gateway", text: $gateway)
                            .font(.system(.body, design: .monospaced))
                            .disabled(isDetectingGateway)
                        
                        if isDetectingGateway {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Detecting...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Picker("Interface", selection: $interface) {
                            Text("Select Interface").tag("")
                            ForEach(activeNetworkPorts, id: \.device) { port in
                                Text(port.displayName).tag(port.device)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(activeNetworkPorts.isEmpty)
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
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Settings") {
                    Toggle("Enable Route", isOn: $isEnabled)
                }
                
                if !isFormValid {
                    Section {
                        Text("Please ensure all fields are filled with valid IP addresses")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Route" : "Add Route")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveRoute()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            Task {
                let networkManager = NetworkManager()
                activeNetworkPorts = await networkManager.getActiveNetworkPorts(using: helperToolManager)
            }
        }
    }
    
    private func saveRoute() {
        if let existingRoute = route {
            existingRoute.updateRoute(
                name: name,
                ipAddress: ipAddress,
                subnetMask: subnetMask,
                gateway: gateway,
                interface: interface,
                isEnabled: isEnabled
            )
        } else {
            let newRoute = Route(
                name: name,
                ipAddress: ipAddress,
                subnetMask: subnetMask,
                gateway: gateway,
                interface: interface,
                isEnabled: isEnabled
            )
            modelContext.insert(newRoute)
        }
        
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
