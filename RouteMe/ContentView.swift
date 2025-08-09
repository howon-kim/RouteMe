//
//  ContentView.swift
//  HelperToolApp
//
//  Created by Alin Lupascu on 2/25/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var helperToolManager = HelperToolManager()
    @StateObject private var networkManager = NetworkManager()
    @State private var commandOutput: String = ""
    @State private var commandToRun: String = "whoami"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack {
                Text(helperToolManager.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        Task {
                            await helperToolManager.manageHelperTool()
                        }
                    }

                Spacer()

                Button(action: {
                    helperToolManager.openSMSettings()
                }) {
                    Label("Settings", systemImage: "gear")
                        .padding(4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)
            }

            Divider()

            // Network Ports Section
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
                    }
                    .frame(height: 200)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            HStack {
                TextField("Enter command here", text: $commandToRun)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await helperToolManager.runCommand(commandToRun) { output in
                                commandOutput = output
                            }
                        }
                    }

                Button(action: {
                    Task {
                        await helperToolManager.runCommand(commandToRun) { output in
                            commandOutput = output
                        }
                    }
                }) {
                    Label("Execute", systemImage: "play")
                        .padding(4)
                }
                .buttonStyle(.borderedProminent)

            }

            ScrollView {
                Text(commandOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.tertiary.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await helperToolManager.manageHelperTool()
            }
        }
    }
}

