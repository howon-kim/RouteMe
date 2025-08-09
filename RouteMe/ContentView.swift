//
//  ContentView.swift
//  HelperToolApp
//
//  Created by Alin Lupascu on 2/25/25.
//

import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable, Identifiable {
    case routes = "Routes"
    case networkPorts = "Network Ports"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .routes:
            return "point.3.connected.trianglepath.dotted"
        case .networkPorts:
            return "network"
        }
    }
}

struct ContentView: View {
    @StateObject private var helperToolManager = HelperToolManager()
    @StateObject private var networkManager = NetworkManager()
    @State private var selectedSidebarItem: SidebarItem = .routes
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            // Main content area
            Group {
                switch selectedSidebarItem {
                case .routes:
                    RoutesView()
                case .networkPorts:
                    NetworkPortsView(networkManager: networkManager, helperToolManager: helperToolManager)
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
        }
        .padding()
    }
}
