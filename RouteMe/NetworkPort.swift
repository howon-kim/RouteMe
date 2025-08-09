//
//  NetworkPort.swift
//  RouteMe
//
//  Created by Howon Kim on 8/5/25.
//

import Foundation
import Combine

struct NetworkPort: Identifiable, Hashable {
    let id = UUID()
    let hardwarePort: String
    let device: String
    let ethernetAddress: String
    let isActive: Bool
    
    var displayName: String {
        return "\(hardwarePort) (\(device))"
    }
    
    var statusText: String {
        return isActive ? "Active" : "Inactive"
    }
}

class NetworkManager: ObservableObject {
    @Published var networkPorts: [NetworkPort] = []
    @Published var isLoading: Bool = false
    
    func parseNetworkSetupOutput(_ output: String) -> [NetworkPort] {
        var ports: [NetworkPort] = []
        let lines = output.components(separatedBy: .newlines)
        
        var currentHardwarePort: String?
        var currentDevice: String?
        var currentEthernetAddress: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("Hardware Port: ") {
                // Save previous port if complete
                if let hardwarePort = currentHardwarePort,
                   let device = currentDevice,
                   let ethernetAddress = currentEthernetAddress {
                    ports.append(NetworkPort(
                        hardwarePort: hardwarePort,
                        device: device,
                        ethernetAddress: ethernetAddress,
                        isActive: false // Will be updated later
                    ))
                }
                
                // Start new port
                currentHardwarePort = String(trimmedLine.dropFirst("Hardware Port: ".count))
                currentDevice = nil
                currentEthernetAddress = nil
            } else if trimmedLine.hasPrefix("Device: ") {
                currentDevice = String(trimmedLine.dropFirst("Device: ".count))
            } else if trimmedLine.hasPrefix("Ethernet Address: ") {
                currentEthernetAddress = String(trimmedLine.dropFirst("Ethernet Address: ".count))
            }
        }
        
        // Don't forget the last port
        if let hardwarePort = currentHardwarePort,
           let device = currentDevice,
           let ethernetAddress = currentEthernetAddress {
            ports.append(NetworkPort(
                hardwarePort: hardwarePort,
                device: device,
                ethernetAddress: ethernetAddress,
                isActive: false // Will be updated later
            ))
        }
        
        return ports
    }
    
    func refreshNetworkPorts(using helperManager: HelperToolManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        await helperManager.runCommand("networksetup -listallhardwareports") { [weak self] output in
            guard let self = self else { return }
            let allPorts = self.parseNetworkSetupOutput(output)
            
            Task {
                let portsWithStatus = await self.addStatusToAllPorts(allPorts, using: helperManager)
                await MainActor.run {
                    self.networkPorts = portsWithStatus
                    self.isLoading = false
                }
            }
        }
    }
    
    func getGatewayForInterface(_ interface: String, using helperManager: HelperToolManager) async -> String? {
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand("route get -ifscope \(interface) 1.1.1.1 | grep gateway") { output in
                    let gateway = self.parseGatewayOutput(output)
                    continuation.resume(returning: gateway)
                }
            }
        }
    }
    
    private func parseGatewayOutput(_ output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.contains("gateway:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count >= 2 {
                    return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    private func addStatusToAllPorts(_ ports: [NetworkPort], using helperManager: HelperToolManager) async -> [NetworkPort] {
        var portsWithStatus: [NetworkPort] = []
        
        for port in ports {
            let isActive = await checkInterfaceStatus(port.device, using: helperManager)
            let updatedPort = NetworkPort(
                hardwarePort: port.hardwarePort,
                device: port.device,
                ethernetAddress: port.ethernetAddress,
                isActive: isActive
            )
            portsWithStatus.append(updatedPort)
        }
        
        return portsWithStatus
    }
    
    func getActiveNetworkPorts(using helperManager: HelperToolManager) async -> [NetworkPort] {
        await MainActor.run {
            isLoading = true
        }
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand("networksetup -listallhardwareports") { [weak self] output in
                    guard let self = self else { 
                        continuation.resume(returning: [])
                        return 
                    }
                    let allPorts = self.parseNetworkSetupOutput(output)
                    
                    Task {
                        let portsWithStatus = await self.addStatusToAllPorts(allPorts, using: helperManager)
                        let activePorts = portsWithStatus.filter { $0.isActive }
                        await MainActor.run {
                            self.isLoading = false
                        }
                        continuation.resume(returning: activePorts)
                    }
                }
            }
        }
    }
    
    private func checkInterfaceStatus(_ interface: String, using helperManager: HelperToolManager) async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand("ifconfig \(interface) | grep status") { output in
                    let isActive = self.parseInterfaceStatus(output)
                    continuation.resume(returning: isActive)
                }
            }
        }
    }
    
    private func parseInterfaceStatus(_ output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.contains("status:") {
                let isActive = !trimmedLine.contains("inactive")
                return isActive
            }
        }
        return true
    }
}
