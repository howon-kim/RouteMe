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
    
    var displayName: String {
        return "\(hardwarePort) (\(device))"
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
                        ethernetAddress: ethernetAddress
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
                ethernetAddress: ethernetAddress
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
            let ports = self.parseNetworkSetupOutput(output)
            Task { @MainActor in
                self.networkPorts = ports
                self.isLoading = false
            }
        }
    }
}
