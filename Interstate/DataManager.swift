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
    @Published var deadEndRoutes: Set<String> = []
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
            
            findDeadEnds()
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
        deadEndRoutes.removeAll()
        hasUnsavedChanges = true
    }
    
    func findDeadEnds() {
        deadEndRoutes.removeAll()
        
        print("🔍 FINDING DEAD ENDS (including interchange connections)...")
        
        // Build a set of all routes that have connections (either from or to)
        var connectedRoutes = Set<String>()
        
        for (fromRoute, routeConnections) in connections {
            if !routeConnections.isEmpty {
                connectedRoutes.insert(fromRoute)
                for connection in routeConnections {
                    connectedRoutes.insert(connection.to)
                }
            }
        }
        
        print("   Routes connected via connections dictionary: \(connectedRoutes.count)")
        
        // Check for routes that share physical endpoints (old style connections)
        let tolerance = 0.000001 // Very small tolerance for coordinate matching
        let allRoutes = Array(interstateRoutes.keys)
        
        for i in 0..<allRoutes.count {
            let route1 = allRoutes[i]
            guard let coords1 = interstateRoutes[route1], !coords1.isEmpty else { continue }
            
            let route1Endpoints = [coords1.first!, coords1.last!]
            
            for j in (i+1)..<allRoutes.count {
                let route2 = allRoutes[j]
                guard let coords2 = interstateRoutes[route2], !coords2.isEmpty else { continue }
                
                let route2Endpoints = [coords2.first!, coords2.last!]
                
                // Check if any endpoints match (within tolerance)
                var foundSharedEndpoint = false
                for endpoint1 in route1Endpoints {
                    for endpoint2 in route2Endpoints {
                        let latDiff = abs(endpoint1.0 - endpoint2.0)
                        let lonDiff = abs(endpoint1.1 - endpoint2.1)
                        
                        if latDiff < tolerance && lonDiff < tolerance {
                            // These routes share a physical endpoint!
                            connectedRoutes.insert(route1)
                            connectedRoutes.insert(route2)
                            foundSharedEndpoint = true
                            print("   Found shared endpoint: \(route1) ↔ \(route2) at (\(String(format: "%.8f", endpoint1.0)), \(String(format: "%.8f", endpoint1.1)))")
                            break
                        }
                    }
                    if foundSharedEndpoint { break }
                }
            }
        }
        
        // NEW: Check for interchange connections (endpoint of one route touching any point on another route)
        let interchangeTolerance = 0.001 // 1km tolerance for interchange detection
        
        for i in 0..<allRoutes.count {
            let routeA = allRoutes[i]
            guard let coordsA = interstateRoutes[routeA], !coordsA.isEmpty else { continue }
            
            let endpointsA = [coordsA.first!, coordsA.last!]
            
            for j in 0..<allRoutes.count {
                if i == j { continue } // Skip self
                
                let routeB = allRoutes[j]
                guard let coordsB = interstateRoutes[routeB], coordsB.count >= 2 else { continue }
                
                // Check if any endpoint of routeA is close to any point on routeB
                for endpointA in endpointsA {
                    // Check against all waypoints in routeB
                    for waypointB in coordsB {
                        let distance = calculateDistance(from: endpointA, to: waypointB)
                        
                        if distance <= interchangeTolerance {
                            // Found an interchange connection!
                            connectedRoutes.insert(routeA)
                            connectedRoutes.insert(routeB)
                            print("   Found interchange connection: \(routeA) endpoint ↔ \(routeB) waypoint")
                            print("      Distance: \(String(format: "%.3f", distance)) km")
                            print("      Connection point: (\(String(format: "%.8f", waypointB.0)), \(String(format: "%.8f", waypointB.1)))")
                            break
                        }
                    }
                }
            }
        }
        
        print("   Total connected routes (including interchanges): \(connectedRoutes.count)")
        
        // Find routes with no connections (neither in connections dict, shared endpoints, nor interchanges)
        for route in interstateRoutes.keys {
            if !connectedRoutes.contains(route) {
                deadEndRoutes.insert(route)
                print("   ❌ Dead end: \(route)")
            }
        }
        
        print("   Final dead ends: \(deadEndRoutes.count)")
        print("✅ Dead end analysis complete!")
    }
    
    func removeDeadEnds() {
        for deadEnd in deadEndRoutes {
            interstateRoutes.removeValue(forKey: deadEnd)
            connections.removeValue(forKey: deadEnd)
        }
        deadEndRoutes.removeAll()
        hasUnsavedChanges = true
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
        
        findDeadEnds()
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
    
    func validateData() {
        // Check for duplicate points
        for (route, coords) in interstateRoutes {
            let uniqueCoords = Set(coords.map { "\($0.0),\($0.1)" })
            if uniqueCoords.count < coords.count {
                print("Warning: Route \(route) has duplicate points")
            }
        }
        
        // Check for invalid connections
        for (fromRoute, routeConnections) in connections {
            for connection in routeConnections {
                if interstateRoutes[connection.to] == nil {
                    print("Warning: Connection from \(fromRoute) to \(connection.to) references non-existent route")
                }
            }
        }
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
        
        // Find dead ends again since we added a new route
        findDeadEnds()
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
        
        // Remove from dead ends set if present
        deadEndRoutes.remove(routeName)
        
        hasUnsavedChanges = true
        
        // Recalculate dead ends
        findDeadEnds()
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