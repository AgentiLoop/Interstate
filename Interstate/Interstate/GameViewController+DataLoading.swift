//
//  GameViewController+DataLoading.swift
//  Interstate
//
//  JSON data loading and position saving
//

import Foundation
import AppKit

extension GameViewController {
    
    // MARK: - JSON Data Loading Functions
    
    func loadInterstateRoutesFromJSON() {
        // LOAD THE ACTUALLY FIXED DATA WITH NO DEAD ENDS!
        guard let jsonPath = Bundle.main.path(forResource: "interstate_routes", ofType: "json") else {
            // Try alternative path during development
            let devPath = "\(FileManager.default.currentDirectoryPath)/Interstate/interstate_routes.json"
            if FileManager.default.fileExists(atPath: devPath) {
                loadInterstateRoutesFromPath(devPath)
            } else {
                // Fallback to old file if new one not found
                print("⚠️ ACTUALLY FIXED data not found, falling back to broken data!")
                if let fallbackPath = Bundle.main.path(forResource: "interstate_routes", ofType: "json") {
                    loadInterstateRoutesFromPath(fallbackPath)
                }
            }
            return
        }
        
        loadInterstateRoutesFromPath(jsonPath)
    }
    
    func loadInterstateRoutesFromPath(_ path: String) {
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
            if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                
                // Load INTERSTATE routes (green, show on radar)
                if let routes = jsonDict["interstateRoutes"] as? [String: [[Double]]] {
                    var loadedRoutes: [String: [(Double, Double)]] = [:]
                    for (routeName, coordinates) in routes {
                        let coordPairs = coordinates.map { coord -> (Double, Double) in
                            return (coord[0], coord[1])
                        }
                        loadedRoutes[routeName] = coordPairs
                    }
                    interstateRoutes = loadedRoutes
                    routeGPSData = loadedRoutes  // Only interstates for radar/GPS
                    print("✅ Loaded \(loadedRoutes.count) interstate routes")
                }
                
                // Load PAVED routes (lighter gray, no radar)
                if let pavedRoutesData = jsonDict["pavedRoutes"] as? [String: [[Double]]] {
                    var loadedPavedRoutes: [String: [(Double, Double)]] = [:]
                    for (routeName, coordinates) in pavedRoutesData {
                        let coordPairs = coordinates.map { coord -> (Double, Double) in
                            return (coord[0], coord[1])
                        }
                        loadedPavedRoutes[routeName] = coordPairs
                    }
                    pavedRoutes = loadedPavedRoutes
                    print("✅ Loaded \(loadedPavedRoutes.count) paved routes")
                }
                
                // Load DIRT routes (orange, no radar)
                if let dirtRoutesData = jsonDict["dirtRoutes"] as? [String: [[Double]]] {
                    var loadedDirtRoutes: [String: [(Double, Double)]] = [:]
                    for (routeName, coordinates) in dirtRoutesData {
                        let coordPairs = coordinates.map { coord -> (Double, Double) in
                            return (coord[0], coord[1])
                        }
                        loadedDirtRoutes[routeName] = coordPairs
                    }
                    dirtRoutes = loadedDirtRoutes
                    print("✅ Loaded \(loadedDirtRoutes.count) dirt routes")
                }
                
                // Load connections if they exist (optional)
                if let connections = jsonDict["connections"] as? [String: [[String: Any]]] {
                    var loadedConnections: [String: [(String, CGFloat, String)]] = [:]
                    
                    for (fromRoute, connList) in connections {
                        var routeConnections: [(String, CGFloat, String)] = []
                        
                        for conn in connList {
                            if let toRoute = conn["to"] as? String,
                               let distance = conn["distance"] as? Double,
                               let type = conn["type"] as? String {
                                routeConnections.append((toRoute, CGFloat(distance), type))
                            }
                        }
                        
                        loadedConnections[fromRoute] = routeConnections
                    }
                    
                    highwayConnections = loadedConnections
                    print("✅ Loaded connections for \(loadedConnections.count) routes")
                }
            }
        } catch {
            print("❌ Error loading route data: \(error)")
        }
    }
    
    func loadMajorCitiesFromJSON() {
        guard let jsonPath = Bundle.main.path(forResource: "major_cities", ofType: "json") else {
            // Try alternative path
            if let alternativePath = Bundle.main.path(forResource: "Interstate/major_cities", ofType: "json") {
                loadMajorCitiesFromPath(alternativePath)
            } else {
                // Try direct file path for development
                let devPath = "\(FileManager.default.currentDirectoryPath)/Interstate/major_cities.json"
                if FileManager.default.fileExists(atPath: devPath) {
                    loadMajorCitiesFromPath(devPath)
                }
            }
            return
        }
        
        loadMajorCitiesFromPath(jsonPath)
    }
    
    func loadMajorCitiesFromPath(_ path: String) {
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
            if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
               let cities = jsonDict["majorCities"] as? [[String: Any]] {
                
                // Convert the loaded data to the expected format
                var loadedCities: [(String, Double, Double, Int)] = []
                for city in cities {
                    if let name = city["name"] as? String,
                       let latitude = city["latitude"] as? Double,
                       let longitude = city["longitude"] as? Double,
                       let population = city["population"] as? Int {
                        loadedCities.append((name, latitude, longitude, population))
                    }
                }
                
                // Assign loaded cities directly
                majorCities = loadedCities
            }
        } catch {
            print("❌ Error loading major cities: \(error)")
        }
    }
    
    // MARK: - Position Saving and Loading
    
    func saveCurrentPosition() {
        // Convert current car position back to GPS coordinates
        let carPos = carNode.position
        let sceneX = Double(carPos.x)
        let sceneZ = Double(carPos.z)
        
        // Reverse the gpsToSceneKit conversion
        let metersEast = sceneX / sceneScale
        let metersNorth = -sceneZ / sceneScale  // Negative because +Z is south in SceneKit
        
        let deltaLon = metersEast / longitudeScale
        let deltaLat = metersNorth / latitudeScale
        
        let currentLat = centerLatitude + deltaLat
        let currentLon = centerLongitude + deltaLon
        
        lastSavedPosition = (currentLat, currentLon)
        
        // Save to UserDefaults for persistence (only when called explicitly)
        UserDefaults.standard.set(currentLat, forKey: "lastCarLatitude")
        UserDefaults.standard.set(currentLon, forKey: "lastCarLongitude")
        
        print("💾 Position saved: \(String(format: "%.6f", currentLat)), \(String(format: "%.6f", currentLon))")
    }
    
    func loadLastPosition() {
        let savedLat = UserDefaults.standard.double(forKey: "lastCarLatitude")
        let savedLon = UserDefaults.standard.double(forKey: "lastCarLongitude")
        
        // If we have valid saved coordinates, use them
        if savedLat != 0.0 && savedLon != 0.0 {
            lastSavedPosition = (savedLat, savedLon)
        } else {
            // First time playing - start in Los Angeles
            lastSavedPosition = (34.0522, -118.2437)
        }
    }
    
    // MARK: - App Termination Listener
    
    func setupAppTerminationListener() {
        // Disable automatic state restoration to prevent frequent UserDefaults writes
        UserDefaults.standard.set(false, forKey: "NSPersistentUIShowQuietSafeQuitStatus")
        UserDefaults.standard.set(false, forKey: "NSWindowRestoreShowsToolbar")
        UserDefaults.standard.set(false, forKey: "NSWindowEnableSavedFrameStringAdditions")
        
        // Listen for app termination notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🛑 App terminating - saving final position...")
            self?.saveCurrentPosition()
        }
        
        // Also listen for window closing (in case user closes window instead of quitting app)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow,
               window == self?.view.window {
                print("🪟 Window closing - saving final position...")
                self?.saveCurrentPosition()
            }
        }
        
        // Listen for app becoming inactive (user switches away)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⏸️ App becoming inactive - saving position...")
            self?.saveCurrentPosition()
        }
        
        print("👂 App termination listeners set up and state restoration disabled")
    }
}
