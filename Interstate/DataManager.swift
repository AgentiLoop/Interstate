import Foundation
import SwiftUI

// Data Models
struct Connection: Codable {
    let to: String
    let distance: Double
    let type: String
    var fromPoint: [Double]?
    var toPoint: [Double]?
    
    enum CodingKeys: String, CodingKey {
        case to, distance, type
        case fromPoint = "from_point"
        case toPoint = "to_point"
    }
}

struct MajorCity: Codable, Identifiable, Equatable {
    let id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var population: Int
    
    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, population
    }
    
    static func == (lhs: MajorCity, rhs: MajorCity) -> Bool {
        lhs.id == rhs.id
    }
}

struct InterstateData: Codable {
    var interstateRoutes: [String: [[Double]]]
    var pavedRoutes: [String: [[Double]]]?
    var dirtRoutes: [String: [[Double]]]?
    var connections: [String: [Connection]]
}

struct CityData: Codable {
    var majorCities: [MajorCity]
}

class DataManager: ObservableObject {
    @Published var interstateRoutes: [String: [(Double, Double)]] = [:]
    @Published var pavedRoutes: [String: [(Double, Double)]] = [:]
    @Published var dirtRoutes: [String: [(Double, Double)]] = [:]
    @Published var connections: [String: [Connection]] = [:]
    @Published var majorCities: [MajorCity] = []
    @Published var hasUnsavedChanges = false
    @Published var isDataLoaded = false
    
    private var interstateDataURL: URL?
    private var cityDataURL: URL?
    
    var sortedRouteNames: [String] {
        interstateRoutes.keys.sorted { route1, route2 in
            // Extract the numeric part for proper sorting
            let num1 = Int(route1.replacingOccurrences(of: "I-", with: "").components(separatedBy: " ").first ?? "") ?? 999
            let num2 = Int(route2.replacingOccurrences(of: "I-", with: "").components(separatedBy: " ").first ?? "") ?? 999
            return num1 < num2
        }
    }
    
    var dirtRoadCount: Int {
        connections.values.flatMap { $0 }.filter { $0.type == "dirt" }.count
    }
    
    var pavedRoadCount: Int {
        connections.values.flatMap { $0 }.filter { $0.type == "paved" }.count
    }
    

    
    // MARK: - File Operations
    
    func loadData() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select interstate_routes_ACTUALLY_FIXED.json"
        openPanel.allowedContentTypes = [.json]
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            loadInterstateData(from: url)
            
            // Try to find major_cities.json in the same directory
            let cityURL = url.deletingLastPathComponent().appendingPathComponent("major_cities.json")
            if FileManager.default.fileExists(atPath: cityURL.path) {
                loadCityData(from: cityURL)
            } else {
                // Ask for city data
                let cityPanel = NSOpenPanel()
                cityPanel.title = "Select major_cities.json"
                cityPanel.allowedContentTypes = [.json]
                if cityPanel.runModal() == .OK, let cityURL = cityPanel.url {
                    loadCityData(from: cityURL)
                }
            }
            
        }
    }
    
    private func loadInterstateData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let interstateData = try decoder.decode(InterstateData.self, from: data)
            
            // Convert array format to tuple format
            self.interstateRoutes = interstateData.interstateRoutes.mapValues { coords in
                coords.map { ($0[0], $0[1]) }
            }
            self.pavedRoutes = (interstateData.pavedRoutes ?? [:]).mapValues { coords in
                coords.map { ($0[0], $0[1]) }
            }
            self.dirtRoutes = (interstateData.dirtRoutes ?? [:]).mapValues { coords in
                coords.map { ($0[0], $0[1]) }
            }
            self.connections = interstateData.connections
            self.interstateDataURL = url
            self.hasUnsavedChanges = false
            self.isDataLoaded = true
            
        } catch {
            print("Error loading interstate data: \(error)")
        }
    }
    
    private func loadCityData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cityData = try decoder.decode(CityData.self, from: data)
            self.majorCities = cityData.majorCities
            self.cityDataURL = url
        } catch {
            print("Error loading city data: \(error)")
        }
    }
    
    func saveData() {
        print("Saving data...")
        saveInterstateData()
        saveCityData()
        hasUnsavedChanges = false
        print("Data saved successfully")
    }
    
    private func saveInterstateData() {
        guard let url = interstateDataURL else { 
            print("Error: No interstate data URL set")
            return 
        }
        
        print("Saving interstate data to: \(url.lastPathComponent)")
        
        // Convert back to array format
        let arrayInterstateRoutes = interstateRoutes.mapValues { coords in
            coords.map { [$0.0, $0.1] }
        }
        let arrayPavedRoutes = pavedRoutes.mapValues { coords in
            coords.map { [$0.0, $0.1] }
        }
        let arrayDirtRoutes = dirtRoutes.mapValues { coords in
            coords.map { [$0.0, $0.1] }
        }
        
        let interstateData = InterstateData(
            interstateRoutes: arrayInterstateRoutes,
            pavedRoutes: arrayPavedRoutes.isEmpty ? nil : arrayPavedRoutes,
            dirtRoutes: arrayDirtRoutes.isEmpty ? nil : arrayDirtRoutes,
            connections: connections
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(interstateData)
            try data.write(to: url)
            print("Successfully saved interstate data (\(arrayInterstateRoutes.count) interstate, \(arrayPavedRoutes.count) paved, \(arrayDirtRoutes.count) dirt routes, \(connections.count) connection groups)")
        } catch {
            print("Error saving interstate data: \(error)")
        }
    }
    
    private func saveCityData() {
        guard let url = cityDataURL else { return }
        
        let cityData = CityData(majorCities: majorCities)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(cityData)
            try data.write(to: url)
        } catch {
            print("Error saving city data: \(error)")
        }
    }
    
    // MARK: - Data Manipulation
    
    func removeAllDirtRoads() {
        print("🗑️ DELETING ALL DIRT ROADS...")
        print("   Before: \(dirtRoutes.count) dirt routes")
        
        // 1. Remove all actual dirt roads
        dirtRoutes.removeAll()
        
        // 2. Remove dirt connections from the connections dictionary
        for (route, routeConnections) in connections {
            connections[route] = routeConnections.filter { $0.type != "dirt" }
        }
        
        hasUnsavedChanges = true
        print("   After: \(dirtRoutes.count) dirt routes")
        print("✅ All dirt roads deleted successfully!")
    }
    
    func removeAllPavedRoads() {
        print("🗑️ DELETING ALL PAVED ROADS...")
        print("   Before: \(pavedRoutes.count) paved routes")
        
        // 1. Remove all actual paved roads
        pavedRoutes.removeAll()
        
        // 2. Remove paved connections from the connections dictionary
        for (route, routeConnections) in connections {
            connections[route] = routeConnections.filter { $0.type != "paved" }
        }
        
        hasUnsavedChanges = true
        print("   After: \(pavedRoutes.count) paved routes")
        print("✅ All paved roads deleted successfully!")
    }
    

    
    func removeAllInterstateRoutes() {
        interstateRoutes.removeAll()
        connections.removeAll()
        hasUnsavedChanges = true
    }
    
    func findDeadEnds() {
        // This function is no longer needed as dead end detection is removed.
        // Keeping it here for now, but it will do nothing.
        print("⚠️ findDeadEnds(): Dead end detection system removed. No action taken.")
    }
    
    func removeDeadEnds() {
        // This function now serves to clear all dead end endpoints
        // Individual dead end endpoints should be fixed by connecting them, not removing entire routes
        print("⚠️ removeDeadEnds(): Dead end endpoints should be fixed by connecting them, not removing routes")
        print("   Current dead end endpoints: 0 (system removed)")
        print("   Use connection tools to fix these endpoints instead of removing routes")
    }
    
    // MARK: - Auto-Connect Interstate to Interstate (Manual Selection)
    
    func autoConnectInterstateToInterstate(fromRoute: String, toRoute: String) {
        guard let fromCoords = interstateRoutes[fromRoute],
              let toCoords = interstateRoutes[toRoute],
              fromCoords.count >= 2,
              toCoords.count >= 2,
              fromRoute != toRoute else {
            print("❌ Invalid routes for interstate connection: \(fromRoute) → \(toRoute)")
            return
        }
        
        print("🔗 AUTO-CONNECTING INTERSTATE ROADS: \(fromRoute) → \(toRoute)")
        
        var modifiedFromCoords = fromCoords
        let fromStart = fromCoords.first!
        let fromEnd = fromCoords.last!
        
        // Find closest point on destination route for both endpoints of source route
        let startResult = findClosestPointOnRoute(targetPoint: fromStart, route: toCoords)
        let endResult = findClosestPointOnRoute(targetPoint: fromEnd, route: toCoords)
        
        // Choose the closer endpoint to connect
        let connectStart = startResult.distance < endResult.distance
        let connectionPoint = connectStart ? startResult.closestPoint : endResult.closestPoint
        let distance = connectStart ? startResult.distance : endResult.distance
        
        print("   📍 \(fromRoute) \(connectStart ? "START" : "END") point:")
        print("      From: (\(String(format: "%.6f", connectStart ? fromStart.0 : fromEnd.0)), \(String(format: "%.6f", connectStart ? fromStart.1 : fromEnd.1)))")
        print("      To: (\(String(format: "%.6f", connectionPoint.0)), \(String(format: "%.6f", connectionPoint.1)))")
        print("      Distance: \(String(format: "%.1f", distance)) km")
        
        // Move the appropriate endpoint
        if connectStart {
            modifiedFromCoords[0] = connectionPoint
        } else {
            modifiedFromCoords[modifiedFromCoords.count - 1] = connectionPoint
        }
        
        // Update the route data
        interstateRoutes[fromRoute] = modifiedFromCoords
        hasUnsavedChanges = true
        
        print("✅ INTERSTATE CONNECTION COMPLETED!")
        print("   \(fromRoute) \(connectStart ? "start" : "end") → \(toRoute)")
        print("   Connection distance: \(String(format: "%.1f", distance)) km")
        
        // Dead end system removed - no update needed
    }
    

    
    // MARK: - Auto-Connect Paved/Dirt Roads to Interstate (Move Endpoints)
    
    func autoConnectPavedToInterstate() {
        var connectionsCreated = 0
        print("🔗 AUTO-CONNECTING PAVED ROADS: Truncating at nearest interstate points...")
        
        for (pavedName, var pavedCoords) in pavedRoutes {
            guard pavedCoords.count >= 2 else { continue }
            
            print("🛣️ Processing paved road: \(pavedName)")
            
            let originalStart = pavedCoords.first!
            let originalEnd = pavedCoords.last!
            
            // Find nearest interstate point for start
            let nearestToStart = findNearestInterstatePoint(to: originalStart)
            
            // Find nearest interstate point for end  
            let nearestToEnd = findNearestInterstatePoint(to: originalEnd)
            
            var modified = false
            
            // Truncate at start if close enough (within 25km)
            if let nearest = nearestToStart, calculateDistance(from: originalStart, to: nearest.point) <= 25.0 {
                // Truncate the paved road at the connection point
                pavedCoords = truncateRoadAtPoint(pavedCoords, targetPoint: nearest.point, fromStart: true)
                modified = true
                connectionsCreated += 1
                print("   ✅ TRUNCATED START at (\(String(format: "%.6f", nearest.point.0)), \(String(format: "%.6f", nearest.point.1))) on \(nearest.routeName)")
                print("      Distance: \(String(format: "%.1f", calculateDistance(from: originalStart, to: nearest.point))) km")
                print("      Road now has \(pavedCoords.count) points (was \(pavedRoutes[pavedName]?.count ?? 0))")
            }
            
            // Truncate at end if close enough and different from start connection
            if let nearest = nearestToEnd, calculateDistance(from: originalEnd, to: nearest.point) <= 25.0 {
                // Make sure we're not connecting both ends to the same point
                if nearestToStart == nil || calculateDistance(from: nearest.point, to: nearestToStart!.point) > 1.0 {
                    // Truncate the paved road at the connection point
                    pavedCoords = truncateRoadAtPoint(pavedCoords, targetPoint: nearest.point, fromStart: false)
                    modified = true
                    connectionsCreated += 1
                    print("   ✅ TRUNCATED END at (\(String(format: "%.6f", nearest.point.0)), \(String(format: "%.6f", nearest.point.1))) on \(nearest.routeName)")
                    print("      Distance: \(String(format: "%.1f", calculateDistance(from: originalEnd, to: nearest.point))) km")
                    print("      Road now has \(pavedCoords.count) points")
                }
            }
            
            if modified {
                pavedRoutes[pavedName] = pavedCoords
                hasUnsavedChanges = true
            }
        }
        
        print("🎉 AUTO-CONNECT PAVED ROADS FINISHED!")
        print("   Modified \(connectionsCreated) paved road endpoints")
        
        // Dead end system removed - no update needed after connections
    }
    
    func autoConnectDirtToInterstate() {
        var connectionsCreated = 0
        print("🔗 AUTO-CONNECTING DIRT ROADS: Truncating at nearest interstate points...")
        
        for (dirtName, var dirtCoords) in dirtRoutes {
            guard dirtCoords.count >= 2 else { continue }
            
            print("🛤️ Processing dirt road: \(dirtName)")
            
            let originalStart = dirtCoords.first!
            let originalEnd = dirtCoords.last!
            
            // Find nearest interstate point for start
            let nearestToStart = findNearestInterstatePoint(to: originalStart)
            
            // Find nearest interstate point for end  
            let nearestToEnd = findNearestInterstatePoint(to: originalEnd)
            
            var modified = false
            
            // Truncate at start if close enough (within 50km for dirt roads)
            if let nearest = nearestToStart, calculateDistance(from: originalStart, to: nearest.point) <= 50.0 {
                // Truncate the dirt road at the connection point
                dirtCoords = truncateRoadAtPoint(dirtCoords, targetPoint: nearest.point, fromStart: true)
                modified = true
                connectionsCreated += 1
                print("   ✅ TRUNCATED START at (\(String(format: "%.6f", nearest.point.0)), \(String(format: "%.6f", nearest.point.1))) on \(nearest.routeName)")
                print("      Distance: \(String(format: "%.1f", calculateDistance(from: originalStart, to: nearest.point))) km")
                print("      Road now has \(dirtCoords.count) points (was \(dirtRoutes[dirtName]?.count ?? 0))")
            }
            
            // Truncate at end if close enough and different from start connection
            if let nearest = nearestToEnd, calculateDistance(from: originalEnd, to: nearest.point) <= 50.0 {
                // Make sure we're not connecting both ends to the same point
                if nearestToStart == nil || calculateDistance(from: nearest.point, to: nearestToStart!.point) > 1.0 {
                    // Truncate the dirt road at the connection point
                    dirtCoords = truncateRoadAtPoint(dirtCoords, targetPoint: nearest.point, fromStart: false)
                    modified = true
                    connectionsCreated += 1
                    print("   ✅ TRUNCATED END at (\(String(format: "%.6f", nearest.point.0)), \(String(format: "%.6f", nearest.point.1))) on \(nearest.routeName)")
                    print("      Distance: \(String(format: "%.1f", calculateDistance(from: originalEnd, to: nearest.point))) km")
                    print("      Road now has \(dirtCoords.count) points")
                }
            }
            
            if modified {
                dirtRoutes[dirtName] = dirtCoords
                hasUnsavedChanges = true
            }
        }
        
        print("🎉 AUTO-CONNECT DIRT ROADS FINISHED!")
        print("   Modified \(connectionsCreated) dirt road endpoints")
        
        // Dead end system removed - no update needed after connections
    }
    
    private func findNearestInterstatePoint(to targetPoint: (Double, Double)) -> (point: (Double, Double), routeName: String)? {
        var nearestPoint: (Double, Double)?
        var nearestRouteName: String?
        var minDistance: Double = Double.infinity
        
        for (routeName, coords) in interstateRoutes {
            for coord in coords {
                let distance = calculateDistance(from: targetPoint, to: coord)
                if distance < minDistance {
                    minDistance = distance
                    nearestPoint = coord
                    nearestRouteName = routeName
                }
            }
        }
        
        if let point = nearestPoint, let routeName = nearestRouteName {
            return (point: point, routeName: routeName)
        }
        return nil
    }
    
    // MARK: - Road Truncation Helper
    
    private func truncateRoadAtPoint(_ roadCoords: [(Double, Double)], targetPoint: (Double, Double), fromStart: Bool) -> [(Double, Double)] {
        guard roadCoords.count >= 2 else { return roadCoords }
        
        var truncatedCoords = roadCoords
        var bestIndex = 0
        var minDistance = Double.infinity
        
        // Find the closest point on the road to the target point
        for i in 0..<roadCoords.count {
            let distance = calculateDistance(from: roadCoords[i], to: targetPoint)
            if distance < minDistance {
                minDistance = distance
                bestIndex = i
            }
        }
        
        if fromStart {
            // Truncate from the start: keep points from closest point to end
            if bestIndex < roadCoords.count - 1 {
                truncatedCoords = Array(roadCoords[bestIndex...])
                // Replace the first point with the exact target point
                truncatedCoords[0] = targetPoint
            }
        } else {
            // Truncate from the end: keep points from start to closest point
            if bestIndex > 0 {
                truncatedCoords = Array(roadCoords[0...bestIndex])
                // Replace the last point with the exact target point
                truncatedCoords[truncatedCoords.count - 1] = targetPoint
            }
        }
        
        // Ensure we always have at least 2 points
        if truncatedCoords.count < 2 {
            if fromStart {
                return [targetPoint, roadCoords.last!]
            } else {
                return [roadCoords.first!, targetPoint]
            }
        }
        
        return truncatedCoords
    }

    func autoConnectRoutes() {
        let maxDistance = 100.0 // Reduced distance for more realistic connections
        var connectionsCreated = 0
        
        print("🔗 SMART INTERCHANGE AUTO-CONNECT: Connecting road endpoints to closest points on other roads...")
        print("📏 MAX DISTANCE: \(maxDistance) km")
        print("🏙️ Using \(majorCities.count) major cities as connection hubs")
        
        // Log current road data for debugging
        print("🗺️ CURRENT ROADS:")
        for (name, coords) in interstateRoutes {
            if !coords.isEmpty {
                print("   \(name): \(coords.count) points")
                print("      Start: (\(String(format: "%.6f", coords.first!.0)), \(String(format: "%.6f", coords.first!.1)))")
                print("      End: (\(String(format: "%.6f", coords.last!.0)), \(String(format: "%.6f", coords.last!.1)))")
            }
        }
        
        // Get all interstate routes 
        let routes = Array(interstateRoutes.keys).sorted()
        
        print("📍 ANALYZING \(routes.count) interstate routes for interchange connections...")
        
        // For each route, find the best interchange connections
        for i in 0..<routes.count {
            let routeA = routes[i]
            guard let coordsA = interstateRoutes[routeA], !coordsA.isEmpty else { continue }
            
            print("🛣️ Analyzing interchange connections for \(routeA)...")
            
            // Get routeA's endpoints
            let endpointsA = [
                (coord: coordsA.first!, isStart: true, routeName: routeA),
                (coord: coordsA.last!, isStart: false, routeName: routeA)
            ]
            
            var bestConnections: [(
                routeA: String, endpointA: (Double, Double), isStartA: Bool,
                routeB: String, closestPointB: (Double, Double), segmentIndexB: Int,
                distance: Double, cityBonus: Double, geoScore: Double, totalScore: Double
            )] = []
            
            // For each endpoint of routeA, find the closest point on all other routes
            for endpointA in endpointsA {
                for j in 0..<routes.count {
                    if i == j { continue } // Skip self
                    
                    let routeB = routes[j]
                    guard let coordsB = interstateRoutes[routeB], coordsB.count >= 2 else { continue }
                    
                    // Find the closest point along the entire length of routeB
                    let closestResult = findClosestPointOnRoute(
                        targetPoint: endpointA.coord,
                        route: coordsB
                    )
                    
                    let distance = closestResult.distance
                    
                    if distance <= maxDistance && distance > 0.01 {
                        print("   🔍 \(routeA) \(endpointA.isStart ? "start" : "end") → \(routeB)")
                        print("      Distance to closest point: \(String(format: "%.1f", distance)) km")
                        print("      Closest point: (\(String(format: "%.6f", closestResult.closestPoint.0)), \(String(format: "%.6f", closestResult.closestPoint.1)))")
                        print("      Segment index: \(closestResult.segmentIndex)")
                        
                        // Calculate bonuses
                        let cityBonus = calculateCityProximityBonus(
                            point1: endpointA.coord,
                            point2: closestResult.closestPoint
                        )
                        
                        let geoScore = calculateGeographicLogicScore(
                            route1: routeA, route1Point: endpointA.coord, route1IsStart: endpointA.isStart,
                            route2: routeB, route2Point: closestResult.closestPoint, route2IsStart: false
                        )
                        
                        // Total score: lower is better
                        let totalScore = distance - (cityBonus * 50.0) - (geoScore * 100.0)
                        
                        print("      City bonus: \(String(format: "%.1f", cityBonus))")
                        print("      Geo score: \(String(format: "%.1f", geoScore))")
                        print("      Total score: \(String(format: "%.1f", totalScore))")
                        
                        bestConnections.append((
                            routeA: routeA, endpointA: endpointA.coord, isStartA: endpointA.isStart,
                            routeB: routeB, closestPointB: closestResult.closestPoint, segmentIndexB: closestResult.segmentIndex,
                            distance: distance, cityBonus: cityBonus, geoScore: geoScore, totalScore: totalScore
                        ))
                    }
                }
            }
            
            // Sort by score and take the best connection for this route
            bestConnections.sort { $0.totalScore < $1.totalScore }
            
            if let bestConnection = bestConnections.first {
                print("🎯 BEST INTERCHANGE CONNECTION for \(routeA):")
                print("   → \(bestConnection.routeB)")
                print("   Distance: \(String(format: "%.1f", bestConnection.distance)) km")
                print("   City bonus: \(String(format: "%.1f", bestConnection.cityBonus))")
                print("   Geo score: \(String(format: "%.1f", bestConnection.geoScore))")
                print("   Total score: \(String(format: "%.1f", bestConnection.totalScore))")
                
                // Check if this connection already exists
                let alreadyConnected = checkIfAlreadyConnected(
                    point1: bestConnection.endpointA,
                    point2: bestConnection.closestPointB
                )
                
                if !alreadyConnected {
                    // Create the interchange connection
                    createInterchangeConnection(
                        routeA: bestConnection.routeA,
                        endpointA: bestConnection.endpointA,
                        isStartA: bestConnection.isStartA,
                        routeB: bestConnection.routeB,
                        closestPointB: bestConnection.closestPointB,
                        segmentIndexB: bestConnection.segmentIndexB
                    )
                    
                    connectionsCreated += 1
                    hasUnsavedChanges = true
                    
                    print("✅ INTERCHANGE CREATED! \(routeA) ↔ \(bestConnection.routeB)")
                    print("   Connection point: (\(String(format: "%.8f", bestConnection.closestPointB.0)), \(String(format: "%.8f", bestConnection.closestPointB.1)))")
                } else {
                    print("⚠️ Already connected, skipping")
                }
            } else {
                print("❌ No suitable interchange connections found for \(routeA)")
            }
        }
        
        print("🎉 SMART INTERCHANGE AUTO-CONNECT FINISHED!")
        print("   Created \(connectionsCreated) interchange connections")
        if connectionsCreated > 0 {
            print("   Roads now connect at realistic interchange points!")
            print("   💾 Don't forget to SAVE your changes!")
        } else {
            print("   No new connections were made")
        }
        
        // Dead end system removed - no update needed
    }
    
    // Helper function to find the closest point on a route to a target point
    private func findClosestPointOnRoute(targetPoint: (Double, Double), route: [(Double, Double)]) -> (closestPoint: (Double, Double), distance: Double, segmentIndex: Int) {
        var minDistance = Double.infinity
        var closestPoint = route[0]
        var bestSegmentIndex = 0
        
        // Check each segment of the route
        for i in 0..<(route.count - 1) {
            let segmentStart = route[i]
            let segmentEnd = route[i + 1]
            
            // Find the closest point on this line segment
            let result = closestPointOnLineSegment(
                point: targetPoint,
                lineStart: segmentStart,
                lineEnd: segmentEnd
            )
            
            if result.distance < minDistance {
                minDistance = result.distance
                closestPoint = result.closestPoint
                bestSegmentIndex = i
            }
        }
        
        return (closestPoint: closestPoint, distance: minDistance, segmentIndex: bestSegmentIndex)
    }
    
    // Helper function to find the closest point on a line segment
    private func closestPointOnLineSegment(point: (Double, Double), lineStart: (Double, Double), lineEnd: (Double, Double)) -> (closestPoint: (Double, Double), distance: Double) {
        let A = point
        let B = lineStart
        let C = lineEnd
        
        // Vector from B to C
        let BC = (C.0 - B.0, C.1 - B.1)
        // Vector from B to A
        let BA = (A.0 - B.0, A.1 - B.1)
        
        // Calculate the parameter t for the closest point
        let dotProduct = BA.0 * BC.0 + BA.1 * BC.1
        let lengthSquared = BC.0 * BC.0 + BC.1 * BC.1
        
        if lengthSquared == 0 {
            // Line segment is actually a point
            let distance = calculateDistance(from: point, to: lineStart)
            return (closestPoint: lineStart, distance: distance)
        }
        
        let t = max(0, min(1, dotProduct / lengthSquared))
        
        // Calculate the closest point
        let closestPoint = (
            B.0 + t * BC.0,
            B.1 + t * BC.1
        )
        
        let distance = calculateDistance(from: point, to: closestPoint)
        return (closestPoint: closestPoint, distance: distance)
    }
    
    // Helper function to create an interchange connection
    private func createInterchangeConnection(
        routeA: String, endpointA: (Double, Double), isStartA: Bool,
        routeB: String, closestPointB: (Double, Double), segmentIndexB: Int
    ) {
        // Update routeA endpoint to match the interchange point
        if var coordsA = interstateRoutes[routeA] {
            if isStartA {
                coordsA[0] = closestPointB
            } else {
                coordsA[coordsA.count - 1] = closestPointB
            }
            interstateRoutes[routeA] = coordsA
            print("   Updated \(routeA) \(isStartA ? "start" : "end") to interchange point")
        }
        
        // Insert the interchange point into routeB if it's not already exactly at a waypoint
        if var coordsB = interstateRoutes[routeB] {
            let segmentStart = coordsB[segmentIndexB]
            let segmentEnd = coordsB[segmentIndexB + 1]
            
            // Check if the closest point is very close to an existing waypoint
            let distanceToStart = calculateDistance(from: closestPointB, to: segmentStart)
            let distanceToEnd = calculateDistance(from: closestPointB, to: segmentEnd)
            
            if distanceToStart < 0.1 { // Within 100m of start point
                // Use the existing start point
                let sharedPoint = segmentStart
                // Update routeA to use this exact point
                if var coordsA = interstateRoutes[routeA] {
                    if isStartA {
                        coordsA[0] = sharedPoint
                    } else {
                        coordsA[coordsA.count - 1] = sharedPoint
                    }
                    interstateRoutes[routeA] = coordsA
                }
                print("   Using existing waypoint at segment start")
            } else if distanceToEnd < 0.1 { // Within 100m of end point
                // Use the existing end point
                let sharedPoint = segmentEnd
                // Update routeA to use this exact point
                if var coordsA = interstateRoutes[routeA] {
                    if isStartA {
                        coordsA[0] = sharedPoint
                    } else {
                        coordsA[coordsA.count - 1] = sharedPoint
                    }
                    interstateRoutes[routeA] = coordsA
                }
                print("   Using existing waypoint at segment end")
            } else {
                // Insert a new interchange point into routeB
                coordsB.insert(closestPointB, at: segmentIndexB + 1)
                interstateRoutes[routeB] = coordsB
                print("   Inserted new interchange waypoint into \(routeB) at index \(segmentIndexB + 1)")
            }
        }
    }
    
    // Helper function to calculate city proximity bonus
    private func calculateCityProximityBonus(point1: (Double, Double), point2: (Double, Double)) -> Double {
        let midpoint = ((point1.0 + point2.0) / 2, (point1.1 + point2.1) / 2)
        var bestBonus = 0.0
        
        // Find the closest major city to the connection midpoint
        for city in majorCities {
            let cityPoint = (city.latitude, city.longitude)
            let distanceToCity = calculateDistance(from: midpoint, to: cityPoint)
            
            // Cities within 100km of connection give bonus, closer = higher bonus
            if distanceToCity <= 100 {
                let bonus = max(0, 10 - distanceToCity / 10) // 10 points at 0km, 0 points at 100km
                bestBonus = max(bestBonus, bonus)
                
                if bonus > 5 {
                    print("      🏙️ Near \(city.name): +\(String(format: "%.1f", bonus)) bonus")
                }
            }
        }
        
        return bestBonus
    }
    
    // Helper function to calculate geographic logic score
    private func calculateGeographicLogicScore(route1: String, route1Point: (Double, Double), route1IsStart: Bool,
                                             route2: String, route2Point: (Double, Double), route2IsStart: Bool) -> Double {
        var score = 0.0
        
        // Bonus for connecting similar numbered interstates (I-80 to I-81, etc)
        if let num1 = extractRouteNumber(from: route1),
           let num2 = extractRouteNumber(from: route2) {
            let numberDiff = abs(num1 - num2)
            if numberDiff <= 5 {
                score += 2.0 // Small bonus for similar numbered routes
                print("      🔢 Similar numbers (\(num1), \(num2)): +2.0 geo bonus")
            }
        }
        
        // Bonus for connecting major cross-country routes
        let majorEastWest = ["I-10", "I-20", "I-40", "I-70", "I-80", "I-90"]
        let majorNorthSouth = ["I-5", "I-15", "I-25", "I-35", "I-55", "I-65", "I-75", "I-85", "I-95"]
        
        let r1IsEW = majorEastWest.contains(route1)
        let r1IsNS = majorNorthSouth.contains(route1)
        let r2IsEW = majorEastWest.contains(route2)
        let r2IsNS = majorNorthSouth.contains(route2)
        
        // Major bonus for connecting east-west with north-south (proper interstate junctions)
        if (r1IsEW && r2IsNS) || (r1IsNS && r2IsEW) {
            score += 5.0
            print("      🛣️ Major route intersection: +5.0 geo bonus")
        }
        
        return score
    }
    
    // Helper function to extract route number from route name
    private func extractRouteNumber(from routeName: String) -> Int? {
        let numberString = routeName.replacingOccurrences(of: "I-", with: "").components(separatedBy: " ").first ?? ""
        return Int(numberString)
    }
    
    // Helper function to check if two points are already connected
    private func checkIfAlreadyConnected(point1: (Double, Double), point2: (Double, Double)) -> Bool {
        let tolerance = 0.001 // 1km tolerance
        
        // Check all existing route endpoints for nearby connections
        for (_, coords) in interstateRoutes {
            if coords.count < 2 { continue }
            
            let endpoints = [coords.first!, coords.last!]
            for endpoint in endpoints {
                let dist1 = calculateDistance(from: point1, to: endpoint)
                let dist2 = calculateDistance(from: point2, to: endpoint)
                
                // If both connection points are very close to the same existing endpoint,
                // they're probably already connected
                if dist1 < tolerance && dist2 < tolerance {
                    return true
                }
            }
        }
        
        return false
    }
    
    func calculateDistance(from: (Double, Double), to: (Double, Double)) -> Double {
        let lat1 = from.0 * .pi / 180
        let lat2 = to.0 * .pi / 180
        let dLat = (to.0 - from.0) * .pi / 180
        let dLon = (to.1 - from.1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1) * cos(lat2) *
                sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let R = 6371.0 // Earth's radius in km
        
        return R * c
    }
    

    
    // MARK: - Route Simplification
    
    func simplifyRoute(_ routeName: String, roadType: String = "interstate", tolerance: Double = 0.001) {
        let coords: [(Double, Double)]?
        
        switch roadType {
        case "interstate":
            coords = interstateRoutes[routeName]
        case "paved":
            coords = pavedRoutes[routeName]
        case "dirt":
            coords = dirtRoutes[routeName]
        default:
            coords = interstateRoutes[routeName]
        }
        
        guard let originalCoords = coords, originalCoords.count > 2 else { 
            print("❌ Cannot simplify route \(routeName): insufficient points or route not found")
            return 
        }
        
        print("🔄 SIMPLIFYING ROUTE: \(routeName)")
        print("   Original points: \(originalCoords.count)")
        print("   Tolerance: \(String(format: "%.6f", tolerance)) degrees (~\(Int(tolerance * 111320)) meters)")
        
        // Step 1: Remove duplicate and near-duplicate points
        var simplified = removeDuplicatePoints(originalCoords, tolerance: tolerance)
        let afterDuplicateRemoval = simplified.count
        
        // Step 2: Remove collinear points (points that don't significantly affect the route shape)
        simplified = removeCollinearPoints(simplified, tolerance: tolerance)
        let afterCollinearRemoval = simplified.count
        
        // Ensure we still have at least 2 points
        if simplified.count < 2 {
            print("❌ Simplification would result in too few points. Keeping original route.")
            return
        }
        
        // Update the route
        switch roadType {
        case "interstate":
            interstateRoutes[routeName] = simplified
        case "paved":
            pavedRoutes[routeName] = simplified
        case "dirt":
            dirtRoutes[routeName] = simplified
        default:
            interstateRoutes[routeName] = simplified
        }
        
        hasUnsavedChanges = true
        
        print("✅ ROUTE SIMPLIFIED:")
        print("   After duplicate removal: \(afterDuplicateRemoval) points")
        print("   After collinear removal: \(afterCollinearRemoval) points")
        print("   Points removed: \(originalCoords.count - simplified.count)")
        print("   Reduction: \(String(format: "%.1f", Double(originalCoords.count - simplified.count) / Double(originalCoords.count) * 100))%")
    }
    
    func simplifyAllRoutes(roadType: String = "interstate", tolerance: Double = 0.001) {
        let routes: [String: [(Double, Double)]]
        
        switch roadType {
        case "interstate":
            routes = interstateRoutes
        case "paved":
            routes = pavedRoutes
        case "dirt":
            routes = dirtRoutes
        default:
            routes = interstateRoutes
        }
        
        print("🔄 SIMPLIFYING ALL \(roadType.uppercased()) ROUTES")
        print("   Routes to process: \(routes.count)")
        print("   Tolerance: \(String(format: "%.6f", tolerance)) degrees")
        
        var totalOriginalPoints = 0
        var totalSimplifiedPoints = 0
        
        for (routeName, _) in routes {
            let originalCount = routes[routeName]?.count ?? 0
            totalOriginalPoints += originalCount
            
            simplifyRoute(routeName, roadType: roadType, tolerance: tolerance)
            
            let newCount: Int
            switch roadType {
            case "interstate":
                newCount = interstateRoutes[routeName]?.count ?? 0
            case "paved":
                newCount = pavedRoutes[routeName]?.count ?? 0
            case "dirt":
                newCount = dirtRoutes[routeName]?.count ?? 0
            default:
                newCount = interstateRoutes[routeName]?.count ?? 0
            }
            totalSimplifiedPoints += newCount
        }
        
        print("✅ ALL ROUTES SIMPLIFIED:")
        print("   Total original points: \(totalOriginalPoints)")
        print("   Total simplified points: \(totalSimplifiedPoints)")
        print("   Total points removed: \(totalOriginalPoints - totalSimplifiedPoints)")
        print("   Overall reduction: \(String(format: "%.1f", Double(totalOriginalPoints - totalSimplifiedPoints) / Double(totalOriginalPoints) * 100))%")
    }
    
    private func removeDuplicatePoints(_ points: [(Double, Double)], tolerance: Double) -> [(Double, Double)] {
        guard points.count > 1 else { return points }
        
        var simplified: [(Double, Double)] = [points[0]] // Always keep first point
        
        for i in 1..<points.count {
            let currentPoint = points[i]
            let lastPoint = simplified.last!
            
            let distance = calculateDistance(from: lastPoint, to: currentPoint)
            let toleranceInKm = tolerance * 111.32 // Convert degrees to approximate km
            
            // Only add point if it's far enough from the last point
            if distance > toleranceInKm {
                simplified.append(currentPoint)
            }
        }
        
        // Always ensure we have the last point if it's different from the last added point
        if simplified.count > 1 && simplified.last! != points.last! {
            let distance = calculateDistance(from: simplified.last!, to: points.last!)
            let toleranceInKm = tolerance * 111.32
            if distance > toleranceInKm {
                simplified.append(points.last!)
            }
        }
        
        return simplified
    }
    
    private func removeCollinearPoints(_ points: [(Double, Double)], tolerance: Double) -> [(Double, Double)] {
        guard points.count > 2 else { return points }
        
        var simplified: [(Double, Double)] = [points[0]] // Always keep first point
        
        for i in 1..<(points.count - 1) {
            let prevPoint = points[i - 1]
            let currentPoint = points[i]
            let nextPoint = points[i + 1]
            
            // Calculate the perpendicular distance from current point to the line between prev and next
            let distance = perpendicularDistance(point: currentPoint, lineStart: prevPoint, lineEnd: nextPoint)
            let toleranceInKm = tolerance * 111.32 // Convert degrees to approximate km
            
            // Only keep the point if it's far enough from the line between its neighbors
            if distance > toleranceInKm {
                simplified.append(currentPoint)
            }
        }
        
        // Always keep the last point
        simplified.append(points.last!)
        
        return simplified
    }
    
    private func perpendicularDistance(point: (Double, Double), lineStart: (Double, Double), lineEnd: (Double, Double)) -> Double {
        let A = lineStart
        let B = lineEnd
        let P = point
        
        // Vector from A to B
        let AB = (B.0 - A.0, B.1 - A.1)
        // Vector from A to P
        let AP = (P.0 - A.0, P.1 - A.1)
        
        // Length of AB
        let ABLength = sqrt(AB.0 * AB.0 + AB.1 * AB.1)
        
        if ABLength == 0 {
            // A and B are the same point, return distance from P to A
            return calculateDistance(from: point, to: lineStart)
        }
        
        // Unit vector in direction of AB
        let ABUnit = (AB.0 / ABLength, AB.1 / ABLength)
        
        // Project AP onto AB
        let projection = AP.0 * ABUnit.0 + AP.1 * ABUnit.1
        
        // Clamp projection to line segment
        let clampedProjection = max(0, min(ABLength, projection))
        
        // Find closest point on line segment
        let closestPoint = (A.0 + clampedProjection * ABUnit.0, A.1 + clampedProjection * ABUnit.1)
        
        // Return distance from P to closest point
        return calculateDistance(from: point, to: closestPoint)
    }

    // MARK: - Route Point Operations
    
    func addPoint(to route: String, at index: Int, coordinate: (Double, Double), roadType: String = "interstate") {
        switch roadType {
        case "interstate":
            guard var routeCoords = interstateRoutes[route] else { return }
            routeCoords.insert(coordinate, at: index)
            interstateRoutes[route] = routeCoords
        case "paved":
            guard var routeCoords = pavedRoutes[route] else { return }
            routeCoords.insert(coordinate, at: index)
            pavedRoutes[route] = routeCoords
        case "dirt":
            guard var routeCoords = dirtRoutes[route] else { return }
            routeCoords.insert(coordinate, at: index)
            dirtRoutes[route] = routeCoords
        default:
            guard var routeCoords = interstateRoutes[route] else { return }
            routeCoords.insert(coordinate, at: index)
            interstateRoutes[route] = routeCoords
        }
        hasUnsavedChanges = true
    }
    
    func updatePoint(in route: String, at index: Int, to coordinate: (Double, Double), roadType: String = "interstate") {
        switch roadType {
        case "interstate":
            guard var routeCoords = interstateRoutes[route],
                  index < routeCoords.count else { return }
            
            // Only update if the coordinate has actually changed significantly
            let currentCoord = routeCoords[index]
            if abs(currentCoord.0 - coordinate.0) < 0.000001 && abs(currentCoord.1 - coordinate.1) < 0.000001 {
                return
            }
            
            routeCoords[index] = coordinate
            interstateRoutes[route] = routeCoords
        case "paved":
            guard var routeCoords = pavedRoutes[route],
                  index < routeCoords.count else { return }
            
            // Only update if the coordinate has actually changed significantly
            let currentCoord = routeCoords[index]
            if abs(currentCoord.0 - coordinate.0) < 0.000001 && abs(currentCoord.1 - coordinate.1) < 0.000001 {
                return
            }
            
            routeCoords[index] = coordinate
            pavedRoutes[route] = routeCoords
        case "dirt":
            guard var routeCoords = dirtRoutes[route],
                  index < routeCoords.count else { return }
            
            // Only update if the coordinate has actually changed significantly
            let currentCoord = routeCoords[index]
            if abs(currentCoord.0 - coordinate.0) < 0.000001 && abs(currentCoord.1 - coordinate.1) < 0.000001 {
                return
            }
            
            routeCoords[index] = coordinate
            dirtRoutes[route] = routeCoords
        default:
            guard var routeCoords = interstateRoutes[route],
                  index < routeCoords.count else { return }
            
            // Only update if the coordinate has actually changed significantly
            let currentCoord = routeCoords[index]
            if abs(currentCoord.0 - coordinate.0) < 0.000001 && abs(currentCoord.1 - coordinate.1) < 0.000001 {
                return
            }
            
            routeCoords[index] = coordinate
            interstateRoutes[route] = routeCoords
        }
        hasUnsavedChanges = true
    }
    
    func deletePoint(from route: String, at index: Int, roadType: String = "interstate") {
        switch roadType {
        case "interstate":
            guard var routeCoords = interstateRoutes[route],
                  index < routeCoords.count,
                  routeCoords.count > 2 else { return } // Keep at least 2 points
            routeCoords.remove(at: index)
            interstateRoutes[route] = routeCoords
        case "paved":
            guard var routeCoords = pavedRoutes[route],
                  index < routeCoords.count,
                  routeCoords.count > 2 else { return } // Keep at least 2 points
            routeCoords.remove(at: index)
            pavedRoutes[route] = routeCoords
        case "dirt":
            guard var routeCoords = dirtRoutes[route],
                  index < routeCoords.count,
                  routeCoords.count > 2 else { return } // Keep at least 2 points
            routeCoords.remove(at: index)
            dirtRoutes[route] = routeCoords
        default:
            guard var routeCoords = interstateRoutes[route],
                  index < routeCoords.count,
                  routeCoords.count > 2 else { return } // Keep at least 2 points
            routeCoords.remove(at: index)
            interstateRoutes[route] = routeCoords
        }
        hasUnsavedChanges = true
    }
    
    // MARK: - Route Creation
    
    func addNewRoute(name: String, points: [(Double, Double)], type: String = "interstate") {
        guard points.count >= 2 else { return }
        
        switch type {
        case "interstate":
            interstateRoutes[name] = points
        case "paved":
            pavedRoutes[name] = points
        case "dirt":
            dirtRoutes[name] = points
        default:
        interstateRoutes[name] = points
        }
        
        hasUnsavedChanges = true
        
        // Dead end system removed - no update needed
    }
    
    func deleteRoute(_ routeName: String, type: String = "interstate") {
        // Remove the route itself
        switch type {
        case "interstate":
            interstateRoutes.removeValue(forKey: routeName)
        case "paved":
            pavedRoutes.removeValue(forKey: routeName)
        case "dirt":
            dirtRoutes.removeValue(forKey: routeName)
        default:
        interstateRoutes.removeValue(forKey: routeName)
        }
        
        // Remove any connections from this route to others
        connections.removeValue(forKey: routeName)
        
        // Remove any connections from other routes to this route
        for (fromRoute, routeConnections) in connections {
            connections[fromRoute] = routeConnections.filter { $0.to != routeName }
        }
        
        // Remove from dead end endpoints set if present
        // deadEndEndpoints.remove("\(routeName)-start") // Removed
        // deadEndEndpoints.remove("\(routeName)-end") // Removed
        
        hasUnsavedChanges = true
        
        // Dead end system removed - no recalculation needed
    }
    
    // MARK: - City Operations
    
    func addCity(_ city: MajorCity) {
        majorCities.append(city)
        hasUnsavedChanges = true
    }
    
    func updateCity(_ city: MajorCity, name: String, latitude: Double, longitude: Double, population: Int) {
        guard let index = majorCities.firstIndex(where: { $0.id == city.id }) else { return }
        majorCities[index].name = name
        majorCities[index].latitude = latitude
        majorCities[index].longitude = longitude
        majorCities[index].population = population
        hasUnsavedChanges = true
    }
    
    func deleteCity(_ city: MajorCity) {
        majorCities.removeAll { $0.id == city.id }
        hasUnsavedChanges = true
    }
    
    // MARK: - Road Operations
    
    func deleteConnection(fromCoordinate: (Double, Double), toCoordinate: (Double, Double), connectionType: String) {
        let tolerance = 0.001 // Small tolerance for coordinate comparison
        
        for (fromRoute, routeConnections) in connections {
            guard let fromRouteCoords = interstateRoutes[fromRoute] else { continue }
            
            for i in 0..<routeConnections.count {
                let connection = routeConnections[i]
                guard connection.type == connectionType else { continue }
                guard let toRouteCoords = interstateRoutes[connection.to] else { continue }
                
                // Check if this connection matches the clicked coordinates
                var matches = false
                
                if let fromPoint = connection.fromPoint, let toPoint = connection.toPoint {
                    // Use specific connection points
                    let fromDiff = abs(fromPoint[0] - fromCoordinate.0) + abs(fromPoint[1] - fromCoordinate.1)
                    let toDiff = abs(toPoint[0] - toCoordinate.0) + abs(toPoint[1] - toCoordinate.1)
                    matches = fromDiff < tolerance && toDiff < tolerance
                } else {
                    // Use route endpoints
                    let fromEndpoints = [fromRouteCoords.first!, fromRouteCoords.last!]
                    let toEndpoints = [toRouteCoords.first!, toRouteCoords.last!]
                    
                    for fromEndpoint in fromEndpoints {
                        for toEndpoint in toEndpoints {
                            let fromDiff = abs(fromEndpoint.0 - fromCoordinate.0) + abs(fromEndpoint.1 - fromCoordinate.1)
                            let toDiff = abs(toEndpoint.0 - toCoordinate.0) + abs(toEndpoint.1 - toCoordinate.1)
                            
                            if fromDiff < tolerance && toDiff < tolerance {
                                matches = true
                                break
                            }
                        }
                        if matches { break }
                    }
                }
                
                if matches {
                    connections[fromRoute]?.remove(at: i)
                    hasUnsavedChanges = true
                    print("Deleted \(connectionType) connection from \(fromRoute) to \(connection.to)")
                    return
                }
            }
        }
    }
    
    // MARK: - Dirt Road Operations
    
    func updateRoadPoint(fromRoute: String, toRoute: String, connectionType: String, isFromPoint: Bool, newCoordinate: (Double, Double)) {
        guard var routeConnections = connections[fromRoute] else { return }
        
        for i in 0..<routeConnections.count {
            if routeConnections[i].to == toRoute && routeConnections[i].type == connectionType {
                if isFromPoint {
                    routeConnections[i].fromPoint = [newCoordinate.0, newCoordinate.1]
                } else {
                    routeConnections[i].toPoint = [newCoordinate.0, newCoordinate.1]
                }
                connections[fromRoute] = routeConnections
                hasUnsavedChanges = true
                break
            }
        }
    }
} 