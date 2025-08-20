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
        
        // Debug output
        print("🚀 [RouteManager] Executing ADD command: \(command)")
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    let success = !output.contains("File exists") && !output.lowercased().contains("error")
                    let message = output.isEmpty ? "Route added successfully" : output
                    
                    // Debug output
                    print("✅ [RouteManager] ADD command result - Success: \(success), Output: '\(output)'")
                    
                    continuation.resume(returning: (success: success, message: message))
                }
            }
        }
    }
    
    /// Adds a network route using gateway instead of interface
    /// - Parameters:
    ///   - ipAddress: The destination network IP address (e.g., "10.76.135.0")
    ///   - subnetMask: The subnet mask (e.g., "255.255.255.0")
    ///   - gateway: The gateway IP address (e.g., "10.0.0.1")
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Success status and output message
    func addRouteUsingGateway(
        ipAddress: String,
        subnetMask: String,
        gateway: String,
        using helperManager: HelperToolManager
    ) async -> (success: Bool, message: String) {
        
        let cidr = subnetMaskToCIDR(subnetMask)
        let command = "sudo route -n add -net \(ipAddress)/\(cidr) \(gateway)"
        
        // Debug output
        print("🚀 [RouteManager] Executing ADD command: \(command)")
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    let success = !output.contains("File exists") && !output.lowercased().contains("error")
                    let message = output.isEmpty ? "Route added successfully" : output
                    
                    // Debug output
                    print("✅ [RouteManager] ADD command result - Success: \(success), Output: '\(output)'")
                    
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
        
        // Debug output
        print("🔥 [RouteManager] Executing REMOVE command: \(command)")
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    let success = !output.lowercased().contains("error") && !output.contains("not in table")
                    let message = output.isEmpty ? "Route removed successfully" : output
                    
                    // Debug output
                    print("❌ [RouteManager] REMOVE command result - Success: \(success), Output: '\(output)'")
                    
                    continuation.resume(returning: (success: success, message: message))
                }
            }
        }
    }
    
    /// Removes a network route using gateway instead of interface
    /// - Parameters:
    ///   - ipAddress: The destination network IP address (e.g., "10.76.135.0")
    ///   - subnetMask: The subnet mask (e.g., "255.255.255.0")
    ///   - gateway: The gateway IP address (e.g., "10.0.0.1")
    ///   - helperManager: The helper tool manager for privileged operations
    /// - Returns: Success status and output message
    func removeRouteUsingGateway(
        ipAddress: String,
        subnetMask: String,
        gateway: String,
        using helperManager: HelperToolManager
    ) async -> (success: Bool, message: String) {
        
        let cidr = subnetMaskToCIDR(subnetMask)
        let command = "sudo route -n delete -net \(ipAddress)/\(cidr) \(gateway)"
        
        // Debug output
        print("🔥 [RouteManager] Executing REMOVE command: \(command)")
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    let success = !output.lowercased().contains("error") && !output.contains("not in table")
                    let message = output.isEmpty ? "Route removed successfully" : output
                    
                    // Debug output
                    print("❌ [RouteManager] REMOVE command result - Success: \(success), Output: '\(output)'")
                    
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
        
        return await addRouteUsingGateway(
            ipAddress: route.ipAddress,
            subnetMask: route.subnetMask,
            gateway: route.gateway,
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
        
        return await removeRouteUsingGateway(
            ipAddress: route.ipAddress,
            subnetMask: route.subnetMask,
            gateway: route.gateway,
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
        
        print("🎯 [RouteManager] Applying \(routes.count) routes to system")
        
        for route in routes {
            let result = await addRoute(route, using: helperManager)
            results.append((route: route, success: result.success, message: result.message))
        }
        
        let successCount = results.filter(\.success).count
        print("📊 [RouteManager] Batch apply completed - \(successCount)/\(results.count) routes applied successfully")
        
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
        
        print("🧹 [RouteManager] Removing \(routes.count) routes from system")
        
        for route in routes {
            let result = await removeRoute(route, using: helperManager)
            results.append((route: route, success: result.success, message: result.message))
        }
        
        let successCount = results.filter(\.success).count
        print("📊 [RouteManager] Batch removal completed - \(successCount)/\(results.count) routes removed successfully")
        
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
    
    /// Checks if a route is active in the system by verifying the gateway
    /// - Parameters:
    ///   - route: The Route to check
    ///   - helperManager: The helper tool manager
    /// - Returns: True if the route is active with the correct gateway
    func isRouteActive(_ route: Route, using helperManager: HelperToolManager) async -> Bool {
        let command = "route -n get \(route.ipAddress)"
        
        return await withCheckedContinuation { continuation in
            Task {
                await helperManager.runCommand(command) { output in
                    // Check if the output contains our expected gateway
                    let isActive = output.contains("gateway: \(route.gateway)")
                    
                    // Debug output
                    print("🔍 [RouteManager] Route status check for \(route.ipAddress):")
                    print("   Expected gateway: \(route.gateway)")
                    print("   Command output: \(output.prefix(200))")
                    print("   Status: \(isActive ? "ACTIVE" : "INACTIVE")")
                    
                    continuation.resume(returning: isActive)
                }
            }
        }
    }
    
    /// Checks the status of multiple routes
    /// - Parameters:
    ///   - routes: Array of routes to check
    ///   - helperManager: The helper tool manager
    /// - Returns: Dictionary mapping route IDs to their active status
    func checkRoutesStatus(_ routes: [Route], using helperManager: HelperToolManager) async -> [UUID: Bool] {
        var statusMap: [UUID: Bool] = [:]
        
        print("🔍 [RouteManager] Checking status of \(routes.count) routes")
        
        for route in routes {
            let isActive = await isRouteActive(route, using: helperManager)
            statusMap[route.id] = isActive
        }
        
        let activeCount = statusMap.values.filter { $0 }.count
        print("📊 [RouteManager] Status check completed - \(activeCount)/\(routes.count) routes are active")
        
        return statusMap
    }
}

// MARK: - String Extension for Padding
private extension String {
    func padLeft(to length: Int, with character: Character) -> String {
        let padCount = max(0, length - self.count)
        return String(repeating: character, count: padCount) + self
    }
}