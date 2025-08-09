//
//  RouteManager.swift
//  RouteMe
//
//  Created by Howon Kim on 8/9/25.
//

import Foundation

class RouteManager {
    static let shared = RouteManager()
    
    private init() {}
    
    // MARK: - Route Management Functions
    
    /// Adds a network route using the interface
    /// - Parameters:
    ///   - ipAddress: The destination network IP address (e.g., "10.76.135.0")
    ///   - subnetMask: The subnet mask (e.g., "255.255.255.0")
    ///   - interface: The network interface (e.g., "en0")
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Success status and output message
    func addRouteUsingInterface(
        ipAddress: String,
        subnetMask: String,
        interface: String,
        using helperManager: HelperToolManager
    ) async -> (success: Bool, message: String) {
        
        let cidr = subnetMaskToCIDR(subnetMask)
        let networkWithCIDR = "\(ipAddress)/\(cidr)"
        let command = "sudo route -n add -net \(networkWithCIDR) -interface \(interface)"
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    let success = !output.contains("File exists") && !output.lowercased().contains("error")
                    let message = output.isEmpty ? "Route added successfully" : output
                    continuation.resume(returning: (success: success, message: message))
                }
            }
        }
    }
    
    /// Removes a network route using the interface
    /// - Parameters:
    ///   - ipAddress: The destination network IP address (e.g., "10.76.135.0")
    ///   - subnetMask: The subnet mask (e.g., "255.255.255.0")
    ///   - interface: The network interface (e.g., "en0")
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Success status and output message
    func removeRouteUsingInterface(
        ipAddress: String,
        subnetMask: String,
        interface: String,
        using helperManager: HelperToolManager
    ) async -> (success: Bool, message: String) {
        
        let cidr = subnetMaskToCIDR(subnetMask)
        let networkWithCIDR = "\(ipAddress)/\(cidr)"
        let command = "sudo route -n delete -net \(networkWithCIDR) -interface \(interface)"
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    let success = !output.lowercased().contains("error") && !output.contains("not in table")
                    let message = output.isEmpty ? "Route removed successfully" : output
                    continuation.resume(returning: (success: success, message: message))
                }
            }
        }
    }
    
    // MARK: - Route Model Integration
    
    /// Adds a route from a Route model to the system routing table
    /// - Parameters:
    ///   - route: The Route model containing route information
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Success status and output message
    func addRoute(
        _ route: Route,
        using helperManager: HelperToolManager
    ) async -> (success: Bool, message: String) {
        
        return await addRouteUsingInterface(
            ipAddress: route.ipAddress,
            subnetMask: route.subnetMask,
            interface: route.interface,
            using: helperManager
        )
    }
    
    /// Removes a route from a Route model from the system routing table
    /// - Parameters:
    ///   - route: The Route model containing route information
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Success status and output message
    func removeRoute(
        _ route: Route,
        using helperManager: HelperToolManager
    ) async -> (success: Bool, message: String) {
        
        return await removeRouteUsingInterface(
            ipAddress: route.ipAddress,
            subnetMask: route.subnetMask,
            interface: route.interface,
            using: helperManager
        )
    }
    
    /// Applies all enabled routes to the system routing table
    /// - Parameters:
    ///   - routes: Array of Route models
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Results for each route application
    func applyRoutes(
        _ routes: [Route],
        using helperManager: HelperToolManager
    ) async -> [(route: Route, success: Bool, message: String)] {
        
        var results: [(route: Route, success: Bool, message: String)] = []
        
        for route in routes where route.isEnabled {
            let result = await addRoute(route, using: helperManager)
            results.append((route: route, success: result.success, message: result.message))
        }
        
        return results
    }
    
    /// Removes all routes from the system routing table
    /// - Parameters:
    ///   - routes: Array of Route models
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Results for each route removal
    func removeRoutes(
        _ routes: [Route],
        using helperManager: HelperToolManager
    ) async -> [(route: Route, success: Bool, message: String)] {
        
        var results: [(route: Route, success: Bool, message: String)] = []
        
        for route in routes {
            let result = await removeRoute(route, using: helperManager)
            results.append((route: route, success: result.success, message: result.message))
        }
        
        return results
    }
    
    // MARK: - Utility Functions
    
    /// Converts subnet mask to CIDR notation
    /// - Parameter subnetMask: Subnet mask in dotted decimal format (e.g., "255.255.255.0")
    /// - Returns: CIDR value (e.g., 24)
    private func subnetMaskToCIDR(_ subnetMask: String) -> Int {
        let components = subnetMask.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return 24 } // Default fallback
        
        var cidr = 0
        for component in components {
            cidr += component.nonzeroBitCount
        }
        
        return cidr
    }
    
    /// Validates if a subnet mask is valid
    /// - Parameter subnetMask: Subnet mask to validate
    /// - Returns: True if valid, false otherwise
    func isValidSubnetMask(_ subnetMask: String) -> Bool {
        let components = subnetMask.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return false }
        
        // Check if all components are valid (0-255)
        for component in components {
            if component < 0 || component > 255 {
                return false
            }
        }
        
        // Check if it's a valid subnet mask pattern
        let binaryString = components.map { String($0, radix: 2).padLeft(to: 8, with: "0") }.joined()
        let ones = binaryString.prefix(while: { $0 == "1" }).count
        let zeros = binaryString.suffix(from: binaryString.index(binaryString.startIndex, offsetBy: ones))
        
        return zeros.allSatisfy { $0 == "0" }
    }
    
    /// Gets current system routes (for debugging/verification)
    /// - Parameter helperManager: The helper tool manager
    /// - Returns: Current routing table output
    func getCurrentRoutes(using helperManager: HelperToolManager) async -> String {
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand("netstat -rn") { output in
                    continuation.resume(returning: output)
                }
            }
        }
    }
}

// MARK: - String Extension for Padding
private extension String {
    func padLeft(to length: Int, with character: Character) -> String {
        let padCount = max(0, length - self.count)
        return String(repeating: character, count: padCount) + self
    }
}