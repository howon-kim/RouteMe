//
//  Route.swift
//  RouteMe
//
//  Created by Howon Kim on 8/9/25.
//

import Foundation
import SwiftData
import CloudKit

@Model
final class Route {
    var id: UUID
    var name: String
    var ipAddress: String
    var subnetMask: String
    var gateway: String
    var interface: String
    var isActive: Bool = false // Tracks actual system status
    var createdAt: Date
    var updatedAt: Date
    
    init(
        name: String,
        ipAddress: String,
        subnetMask: String,
        gateway: String,
        interface: String
    ) {
        self.id = UUID()
        self.name = name
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.gateway = gateway
        self.interface = interface
        self.isActive = false // Initially not active in system
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateRoute(
        name: String? = nil,
        ipAddress: String? = nil,
        subnetMask: String? = nil,
        gateway: String? = nil,
        interface: String? = nil,
        isActive: Bool? = nil
    ) {
        if let name = name { self.name = name }
        if let ipAddress = ipAddress { self.ipAddress = ipAddress }
        if let subnetMask = subnetMask { self.subnetMask = subnetMask }
        if let gateway = gateway { self.gateway = gateway }
        if let interface = interface { self.interface = interface }
        if let isActive = isActive { self.isActive = isActive }
        self.updatedAt = Date()
    }
    
    var displayDescription: String {
        "\(ipAddress)/\(subnetMask) via \(gateway) on \(interface)"
    }
    
    func isValidIPAddress(_ ip: String) -> Bool {
        let ipRegex = #"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        return ip.range(of: ipRegex, options: .regularExpression) != nil
    }
    
    var isValid: Bool {
        return !name.isEmpty &&
               isValidIPAddress(ipAddress) &&
               RouteManager.shared.isValidSubnetMask(subnetMask) &&
               isValidIPAddress(gateway) &&
               !interface.isEmpty
    }
    
    /// Applies this route to the system routing table
    /// - Parameter helperManager: Helper tool manager for privileged operations
    /// - Returns: Success status and message
    func applyToSystem(using helperManager: HelperToolManager) async -> (success: Bool, message: String) {
        return await RouteManager.shared.addRoute(self, using: helperManager)
    }
    
    /// Removes this route from the system routing table
    /// - Parameter helperManager: Helper tool manager for privileged operations
    /// - Returns: Success status and message
    func removeFromSystem(using helperManager: HelperToolManager) async -> (success: Bool, message: String) {
        return await RouteManager.shared.removeRoute(self, using: helperManager)
    }
    
    /// Checks if this route is actually active in the system
    /// - Parameter helperManager: Helper tool manager for privileged operations
    /// - Returns: True if route is active in system with correct gateway
    func checkSystemStatus(using helperManager: HelperToolManager) async -> Bool {
        return await RouteManager.shared.isRouteActive(self, using: helperManager)
    }
    
    /// Updates the route's active status based on system check
    /// - Parameter helperManager: Helper tool manager for privileged operations
    func refreshSystemStatus(using helperManager: HelperToolManager) async {
        let actualStatus = await checkSystemStatus(using: helperManager)
        isActive = actualStatus
        updatedAt = Date()
    }
}

extension Route {
    static var sampleRoutes: [Route] {
        [
            Route(
                name: "Home Network",
                ipAddress: "192.168.1.0",
                subnetMask: "255.255.255.0",
                gateway: "192.168.1.1",
                interface: "en0"
            ),
            Route(
                name: "VPN Route",
                ipAddress: "10.0.0.0",
                subnetMask: "255.255.0.0",
                gateway: "10.0.0.1",
                interface: "utun0"
            )
        ]
    }
}