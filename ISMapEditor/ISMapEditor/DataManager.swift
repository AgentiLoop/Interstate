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
        for (route, routeConnections) in connections {
            connections[route] = routeConnections.filter { $0.type != "dirt" }
        }
        hasUnsavedChanges = true
    }
    
    func removeAllPavedRoads() {
        for (route, routeConnections) in connections {
            connections[route] = routeConnections.filter { $0.type != "paved" }
        }
        hasUnsavedChanges = true
    }
    

    
    func removeAllInterstateRoutes() {
        interstateRoutes.removeAll()
        connections.removeAll()
        deadEndRoutes.removeAll()
        hasUnsavedChanges = true
    }
    
    func findDeadEnds() {
        deadEndRoutes.removeAll()
        
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
        
        // Find routes with no connections
        for route in interstateRoutes.keys {
            if !connectedRoutes.contains(route) {
                deadEndRoutes.insert(route)
            }
        }
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
        let maxDistance = 50.0 // Maximum distance in km to auto-connect
        
        for route1 in sortedRouteNames {
            guard let coords1 = interstateRoutes[route1], !coords1.isEmpty else { continue }
            
            let endpoints1 = [coords1.first!, coords1.last!]
            
            for route2 in sortedRouteNames {
                guard route1 != route2,
                      let coords2 = interstateRoutes[route2],
                      !coords2.isEmpty else { continue }
                
                let endpoints2 = [coords2.first!, coords2.last!]
                
                // Check all endpoint combinations
                for (_, endpoint1) in endpoints1.enumerated() {
                    for (_, endpoint2) in endpoints2.enumerated() {
                        let distance = calculateDistance(from: endpoint1, to: endpoint2)
                        
                        if distance < maxDistance && distance > 0.1 {
                            // Check if connection already exists
                            let existingConnections = connections[route1] ?? []
                            let alreadyConnected = existingConnections.contains { $0.to == route2 }
                            
                            if !alreadyConnected {
                                // Create paved connection
                                let newConnection = Connection(
                                    to: route2,
                                    distance: distance,
                                    type: "paved",
                                    fromPoint: [endpoint1.0, endpoint1.1],
                                    toPoint: [endpoint2.0, endpoint2.1]
                                )
                                
                                if connections[route1] == nil {
                                    connections[route1] = []
                                }
                                connections[route1]?.append(newConnection)
                                hasUnsavedChanges = true
                            }
                        }
                    }
                }
            }
        }
        
        findDeadEnds()
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
    
    func addPoint(to route: String, at index: Int, coordinate: (Double, Double)) {
        guard var routeCoords = interstateRoutes[route] else { return }
        routeCoords.insert(coordinate, at: index)
        interstateRoutes[route] = routeCoords
        hasUnsavedChanges = true
    }
    
    func updatePoint(in route: String, at index: Int, to coordinate: (Double, Double)) {
        guard var routeCoords = interstateRoutes[route],
              index < routeCoords.count else { return }
        
        // Only update if the coordinate has actually changed significantly
        let currentCoord = routeCoords[index]
        if abs(currentCoord.0 - coordinate.0) < 0.000001 && abs(currentCoord.1 - coordinate.1) < 0.000001 {
            return
        }
        
        routeCoords[index] = coordinate
        interstateRoutes[route] = routeCoords
        hasUnsavedChanges = true
    }
    
    func deletePoint(from route: String, at index: Int) {
        guard var routeCoords = interstateRoutes[route],
              index < routeCoords.count,
              routeCoords.count > 2 else { return } // Keep at least 2 points
        routeCoords.remove(at: index)
        interstateRoutes[route] = routeCoords
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