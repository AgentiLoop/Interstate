//
//  GameViewController+RoadSystem.swift
//  Interstate
//
//  Dynamic road loading and creation system
//

import SceneKit
import AppKit
import Foundation

extension GameViewController {
    
    // MARK: - SIMPLE ROAD LOADING SYSTEM
    // Based on 3D game LOD and streaming best practices
    
    // SIMPLE ROAD LOADING SYSTEM - Based on 3D game LOD and streaming best practices
    
    // Reduce frequency counters moved to main GameViewController class
    
    // Single update function - called from game loop
    func updateDynamicRoads() {
        guard let playerNode = carNode else { return }
        
        // INTERSECTION FIX - Load nearby roads for proper intersections
        let SEGMENT_LOAD_DISTANCE: CGFloat = 3000.0    // Increased to load intersection roads
        let SEGMENT_UNLOAD_DISTANCE: CGFloat = 4000.0  // Increased accordingly
        let MAX_SEGMENTS: Int = 20                   // INCREASED to load intersection roads
        let MIN_SEGMENTS: Int = 3                   // Reasonable minimum
        
        // STALL PREVENTION - Only update every 8 frames to prevent constant loading
        // BUT: Always update on first few frames when no roads are loaded
        roadUpdateCounter += 1
        if roadUpdateCounter % 8 != 0 && loadedRoadSegments.count > 10 { return }
        
        let playerPosition = playerNode.position
        
        // FLOATING POINT PRECISION FIX - World origin rebasing DISABLED
        // checkAndRebaseWorldOrigin(playerPosition: playerPosition) // DISABLED - NEVER RESET CAR POSITION
        
        // Get current segment count
        let currentSegmentCount = loadedRoadSegments.count
        
        // Phase 1: STRICT EMERGENCY unloading if over user's limit
        if currentSegmentCount > MAX_SEGMENTS {
            emergencyUnload(playerPosition: playerPosition, maxSegments: MAX_SEGMENTS)
            return // Don't load anything when over limit - USER REQUIREMENT
        }
        
        // Phase 2: Regular unloading of distant segments  
        unloadDistantSegments(playerPosition: playerPosition, unloadDistance: SEGMENT_UNLOAD_DISTANCE)
        
        // Phase 3: Load nearby segments - ALWAYS try to load if under limit
        if loadedRoadSegments.count < MAX_SEGMENTS { 
            loadNearbySegments(playerPosition: playerPosition, loadDistance: SEGMENT_LOAD_DISTANCE, maxSegments: MAX_SEGMENTS)
        }
        
        // Update HUD with current status
        updateSegmentHUD(maxSegments: MAX_SEGMENTS)
    }
    
    // MARK: - Emergency Unloading
    private func emergencyUnload(playerPosition: SCNVector3, maxSegments: Int) {
        // Calculate distances to all loaded segments
        var segmentDistances: [(String, CGFloat)] = []
        
        for (segmentKey, _) in loadedRoadSegments {
            let distance = calculateSegmentDistance(segmentKey: segmentKey, playerPosition: playerPosition)
            segmentDistances.append((segmentKey, distance))
        }
        
        // Sort by distance (farthest first)
        segmentDistances.sort { $0.1 > $1.1 }
        
        // Unload the farthest segments until we're at the limit
        let segmentsToUnload = segmentDistances.count - maxSegments
        for i in 0..<segmentsToUnload {
            let segmentKey = segmentDistances[i].0
            unloadRoadSegment(segmentKey: segmentKey)
        }
    }
    
    // MARK: - Regular Unloading
    private func unloadDistantSegments(playerPosition: SCNVector3, unloadDistance: CGFloat) {
        var segmentsToUnload: [String] = []
        
        for (segmentKey, _) in loadedRoadSegments {
            let distance = calculateSegmentDistance(segmentKey: segmentKey, playerPosition: playerPosition)
            
            if distance > unloadDistance {
                segmentsToUnload.append(segmentKey)
            }
        }
        
        for segmentKey in segmentsToUnload {
            unloadRoadSegment(segmentKey: segmentKey)
        }
    }
    
    // MARK: - Loading Nearby Segments
    private func loadNearbySegments(playerPosition: SCNVector3, loadDistance: CGFloat, maxSegments: Int) {
        // Load from ALL route types: interstate, paved, and dirt
        var allRoutes: [String: [(Double, Double)]] = [:]
        
        // Add interstate routes (green) - HIGHEST PRIORITY
        for (name, coords) in interstateRoutes {
            // Filter out short road artifacts at loading time
            let routeLength = calculateRouteLength(coords: coords)
            let FIVE_MILES_IN_METERS: Double = 8046.72 // 5 miles
            
            if routeLength >= FIVE_MILES_IN_METERS {
                allRoutes[name] = coords
            } else {
                print("🗑️ Skipped short interstate artifact: \(name) (\(Int(routeLength/1000))km)")
            }
        }
        
        // Add paved routes (light gray) - MEDIUM PRIORITY  
        for (name, coords) in pavedRoutes {
            // Filter out short road artifacts at loading time
            let routeLength = calculateRouteLength(coords: coords)
            let FIVE_MILES_IN_METERS: Double = 8046.72 // 5 miles
            
            if routeLength >= FIVE_MILES_IN_METERS {
                allRoutes["paved_\(name)"] = coords
            } else {
                print("🗑️ Skipped short paved artifact: \(name) (\(Int(routeLength/1000))km)")
            }
        }
        
        // Add dirt roads (allow shorter lengths - 2 miles minimum for rural roads)
        for (name, coords) in dirtRoutes {
            let routeLength = calculateRouteLength(coords: coords)
            let TWO_MILES_IN_METERS: Double = 3218.69 // 2 miles for dirt roads
            
            if routeLength >= TWO_MILES_IN_METERS {
                allRoutes["dirt_\(name)"] = coords
            } else {
                print("🗑️ Skipped short dirt artifact: \(name) (\(Int(routeLength/1000))km)")
            }
        }
        
        // DEBUG: Log road counts for troubleshooting
        if roadUpdateCounter % 480 == 0 { // Log every 8 seconds
            print("🛣️ Road Loading Status:")
            print("   - Interstate routes: \(interstateRoutes.count)")
            print("   - Paved routes: \(pavedRoutes.count)")
            print("   - Dirt routes: \(dirtRoutes.count)")
            print("   - Total routes available: \(allRoutes.count)")
            
            if pavedRoutes.count > 0 {
                print("   - Paved route names: \(Array(pavedRoutes.keys).prefix(3))")
            }
            if dirtRoutes.count > 0 {
                print("   - Dirt route names: \(Array(dirtRoutes.keys).prefix(3))")
            }
        }
        
        // Add water bodies (blue)
        for (name, coords) in waterBodies {
            allRoutes["water_\(name)"] = coords
        }
        
        // Add coastlines (blue-green)
        for (name, coords) in coastlines {
            allRoutes["coast_\(name)"] = coords
        }
        
        if allRoutes.isEmpty {
            return
        }
        
        // INTERSECTION FIX: Load segments from ALL nearby routes, not just closest
        var segmentsToLoad: [(String, CGFloat)] = []
        
        // Check ALL routes for nearby segments
        for (routeName, routeData) in allRoutes {
            let smoothPoints = generateSmoothRoadPoints(from: routeData)
            let segmentLength = 500 // Points per smooth curve segment
            let totalSegments = (smoothPoints.count + segmentLength - 1) / segmentLength
            
            // Check each segment of this route
            for segmentIndex in 0..<totalSegments {
                let segmentKey = "\(routeName)_\(segmentIndex)"
                
                // Skip if already loaded
                if loadedRoadSegments[segmentKey] != nil { continue }
                
                // Check if this segment is close to the player
                let startIndex = segmentIndex * segmentLength
                let endIndex = min(startIndex + segmentLength, smoothPoints.count - 1)
                
                // Sample a few points from this segment to check distance
                var minDistanceToSegment: CGFloat = CGFloat.infinity
                for i in stride(from: startIndex, to: endIndex, by: 50) { // Sample every 50 points
                    let point = smoothPoints[i]
                    let segmentPosition = SCNVector3(point.0, 0, point.1)
                    let distance = calculateDistance(from: playerPosition, to: segmentPosition)
                    minDistanceToSegment = min(minDistanceToSegment, distance)
                }
                
                if minDistanceToSegment <= loadDistance {
                    segmentsToLoad.append((segmentKey, minDistanceToSegment))
                }
            }
        }
        
        // Sort by distance (closest first)
        segmentsToLoad.sort { $0.1 < $1.1 }
        
        // Load segments until we hit the limit
        for (segmentKey, _) in segmentsToLoad {
            if loadedRoadSegments.count >= maxSegments { break }
            
            // Extract route name from segment key
            let components = segmentKey.split(separator: "_")
            let routeName = components.dropLast().joined(separator: "_")
            
            loadRoadSegment(segmentKey: segmentKey, routeName: routeName)
        }
        
        // Clean up intersection overlaps after loading segments
        cleanupIntersectionOverlaps(playerPosition: playerPosition)
        
        // Remove any short road artifacts that might have been loaded
        removeShortRoadArtifacts()
    }
    
    // MARK: - World Origin Rebasing (Floating Point Precision Fix)
    
    private func checkAndRebaseWorldOrigin(playerPosition: SCNVector3) {
        // FLOATING POINT PRECISION: When coordinates get too large, precision is lost
        // causing jitter, stalls, and rendering problems. Rebase when player is far from origin.
        
        let REBASE_THRESHOLD: CGFloat = 50000.0 // When player is 50km from origin (much better for gameplay)
        let REBASE_DISTANCE: CGFloat = 30000.0  // How far they've moved since last rebase
        
        let distanceFromOrigin = sqrt(playerPosition.x * playerPosition.x + 
                                    playerPosition.z * playerPosition.z)
        
        let distanceFromLastRebase = sqrt(pow(playerPosition.x - lastWorldOriginRebase.x, 2) + 
                                        pow(playerPosition.z - lastWorldOriginRebase.z, 2))
        
        if distanceFromOrigin > REBASE_THRESHOLD && distanceFromLastRebase > REBASE_DISTANCE {
            print("🔄 WORLD ORIGIN REBASING: Player at (\(Int(playerPosition.x)), \(Int(playerPosition.z))) - precision loss risk")
            performWorldOriginRebase(playerPosition: playerPosition)
        }
    }
    
    private func performWorldOriginRebase(playerPosition: SCNVector3) {
        // WORLD ORIGIN REBASING: Move everything back toward origin to restore precision
        // This is a proven technique used in large world games
        
        let rebaseOffset = SCNVector3(-playerPosition.x, 0, -playerPosition.z)
        
        // Move the car back to origin
        let carY = carNode.position.y
        carNode.position = SCNVector3(0, carY, 0)
        
        // Move all loaded road segments by the offset
        for (_, roadNode) in loadedRoadSegments {
            let currentX = roadNode.position.x
            let currentY = roadNode.position.y
            let currentZ = roadNode.position.z
            let newX = currentX + rebaseOffset.x
            let newZ = currentZ + rebaseOffset.z
            roadNode.position = SCNVector3(newX, currentY, newZ)
        }
        
        // Move all loaded checkpoints by the offset
        var newCheckpointPositions: [String: (SCNVector3, Int)] = [:]
        for (cityName, (position, population)) in checkpointPositions {
            let currentX = position.x
            let currentY = position.y
            let currentZ = position.z
            let newX = currentX + rebaseOffset.x
            let newZ = currentZ + rebaseOffset.z
            let newPosition = SCNVector3(newX, currentY, newZ)
            newCheckpointPositions[cityName] = (newPosition, population)
        }
        checkpointPositions = newCheckpointPositions
        
        // Update tracking
        lastWorldOriginRebase = playerPosition
        
        let offsetX = Int(rebaseOffset.x)
        let offsetZ = Int(rebaseOffset.z)
        print("✅ World origin rebased: offset (\(offsetX), \(offsetZ))")
    }
    
    // MARK: - Helper Functions
    
    /// Calculate distance between two 3D points
    internal func calculateDistance(from point1: SCNVector3, to point2: SCNVector3) -> CGFloat {
        let deltaX = point1.x - point2.x
        let deltaY = point1.y - point2.y
        let deltaZ = point1.z - point2.z
        return sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
    }
    
    private func findClosestRoute(to position: SCNVector3) -> String? {
        return findClosestRouteIn(routes: routeGPSData, to: position)
    }
    
    private func findClosestRouteIn(routes: [String: [(Double, Double)]], to position: SCNVector3) -> String? {
        var closestRoute: String?
        var closestDistance: CGFloat = CGFloat.infinity
        
        for (routeName, routeData) in routes {
            for (lat, lon) in routeData {
                let routePosition = gpsToSceneKit(latitude: lat, longitude: lon)
                let distance = calculateDistance(from: position, to: routePosition)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestRoute = routeName
                }
            }
        }
        
        return closestRoute
    }
    
    internal func calculateSegmentDistance(segmentKey: String, playerPosition: SCNVector3) -> CGFloat {
        // Extract route name and segment index from segment key
        let components = segmentKey.split(separator: "_")
        guard components.count >= 2,
              let segmentIndex = Int(components.last!) else { return CGFloat.infinity }
        
        let routeName = components.dropLast().joined(separator: "_")
        
        // Look in all route types
        var routeData: [(Double, Double)]?
        
        if let data = interstateRoutes[routeName] {
            routeData = data
            print("🛣️ Found interstate data for: \(routeName)")
        } else if routeName.hasPrefix("paved_"), let data = pavedRoutes[String(routeName.dropFirst(6))] {
            routeData = data
            print("🛣️ Found paved data for: \(routeName) → \(String(routeName.dropFirst(6)))")
        } else if routeName.hasPrefix("dirt_"), let data = dirtRoutes[String(routeName.dropFirst(5))] {
            routeData = data
            print("🛤️ Found dirt data for: \(routeName) → \(String(routeName.dropFirst(5)))")
        } else if routeName.hasPrefix("water_"), let data = waterBodies[String(routeName.dropFirst(6))] {
            routeData = data
            print("🌊 Found water data for: \(routeName)")
        } else if routeName.hasPrefix("coast_"), let data = coastlines[String(routeName.dropFirst(6))] {
            routeData = data
            print("🏖️ Found coast data for: \(routeName)")
        } else {
            print("❌ No route data found for: \(routeName)")
        }
        
        guard let routeCoords = routeData else { return CGFloat.infinity }
        
        // Generate smooth points and find closest point in this segment
        let smoothPoints = generateSmoothRoadPoints(from: routeCoords)
        let segmentLength = 500
        
        let startIndex = segmentIndex * segmentLength
        guard startIndex < smoothPoints.count else { return CGFloat.infinity }
        
        let endIndex = min(startIndex + segmentLength, smoothPoints.count - 1)
        
        // Find closest point in this segment
        var minDistance: CGFloat = CGFloat.infinity
        for i in startIndex...endIndex {
            let point = smoothPoints[i]
            let segmentPosition = SCNVector3(point.0, 0, point.1)
            let distance = calculateDistance(from: playerPosition, to: segmentPosition)
            minDistance = min(minDistance, distance)
        }
        
        return minDistance
    }
    
    // MARK: - Route Length Calculation for Artifact Filtering
    
    private func calculateRouteLength(coords: [(Double, Double)]) -> Double {
        guard coords.count >= 2 else { return 0.0 }
        
        var totalLength: Double = 0.0
        
        for i in 0..<coords.count-1 {
            let point1 = coords[i]
            let point2 = coords[i+1]
            
            // Convert GPS to scene coordinates to get accurate distances
            let pos1 = gpsToSceneKit(latitude: point1.0, longitude: point1.1)
            let pos2 = gpsToSceneKit(latitude: point2.0, longitude: point2.1)
            
            // Calculate distance between consecutive points
            let segmentLength = sqrt(pow(pos2.x - pos1.x, 2) + pow(pos2.z - pos1.z, 2))
            totalLength += Double(segmentLength)
        }
        
        return totalLength
    }
    
    private func removeShortRoadArtifacts() {
        var segmentsToRemove: [String] = []
        
        for (segmentKey, segmentNode) in loadedRoadSegments {
            // Extract route name from segment key
            let components = segmentKey.split(separator: "_")
            guard components.count >= 2 else { continue }
            
            let routeName = components.dropLast().joined(separator: "_")
            
            // Get the route data to check length
            var routeData: [(Double, Double)]?
            
            if routeName.hasPrefix("dirt_") {
                let cleanName = String(routeName.dropFirst(5))
                routeData = dirtRoutes[cleanName]
            } else if routeName.hasPrefix("paved_") {
                let cleanName = String(routeName.dropFirst(6))
                routeData = pavedRoutes[cleanName]
            } else {
                routeData = interstateRoutes[routeName]
            }
            
            if let coords = routeData {
                let routeLength = calculateRouteLength(coords: coords)
                let minLength: Double = routeName.hasPrefix("dirt_") ? 3218.69 : 8046.72 // 2 miles for dirt, 5 miles for others
                
                if routeLength < minLength {
                    segmentsToRemove.append(segmentKey)
                    print("🗑️ Removing loaded short artifact: \(routeName) (\(Int(routeLength/1000))km)")
                }
            }
        }
        
        // Remove the short segments
        for segmentKey in segmentsToRemove {
            unloadRoadSegment(segmentKey: segmentKey)
        }
    }
    
    private func removeAllRoadMarkingsFromNode(_ roadNode: SCNNode) {
        // AGGRESSIVELY remove ALL road markings (white lines, yellow lines, etc.)
        var markingNodesToRemove: [SCNNode] = []
        
        roadNode.enumerateChildNodes { (node, _) in
            // Remove ANY child node that looks like a road marking
            if let geometry = node.geometry as? SCNBox {
                // If it's a small box (likely a road marking), remove it
                if geometry.height < 0.2 && geometry.width < 15.0 {
                    markingNodesToRemove.append(node)
                }
            }
        }
        
        // Remove all identified marking nodes
        for markingNode in markingNodesToRemove {
            markingNode.removeFromParentNode()
        }
        
        print("🗑️ Removed \(markingNodesToRemove.count) road marking elements")
    }
    
    private func isAtIntersectionWithHigherPriorityRoad(routeName: String, points: [(CGFloat, CGFloat)]) -> Bool {
        // Determine priority of this route
        let currentPriority: Int
        if routeName.hasPrefix("dirt_") {
            currentPriority = 1
        } else if routeName.hasPrefix("paved_") {
            currentPriority = 2
        } else {
            currentPriority = 3 // Interstate
        }
        
        // Check if any point of this route is near a higher priority loaded road
        let intersectionRadius: CGFloat = 30.0
        
        for point in points.prefix(10) { // Check first 10 points for performance
            let checkPosition = SCNVector3(point.0, 0, point.1)
            
            // Check against all loaded road segments
            for (segmentKey, segmentNode) in loadedRoadSegments {
                let segmentPosition = segmentNode.position
                let distance = calculateDistance(from: checkPosition, to: segmentPosition)
                
                if distance <= intersectionRadius {
                    // Determine priority of the loaded segment
                    let segmentPriority: Int
                    if segmentKey.contains("dirt_") {
                        segmentPriority = 1
                    } else if segmentKey.contains("paved_") {
                        segmentPriority = 2
                    } else {
                        segmentPriority = 3 // Interstate
                    }
                    
                    // If we found a higher priority road nearby, skip markings
                    if segmentPriority > currentPriority {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Intersection Detection for Road Markings
    
    private func isPointNearIntersection(_ point: SCNVector3, radius: CGFloat) -> Bool {
        // Count how many different road segments are near this point
        var nearbySegmentCount = 0
        
        for (segmentKey, segmentNode) in loadedRoadSegments {
            let segmentPosition = segmentNode.position
            let distance = calculateDistance(from: point, to: segmentPosition)
            
            if distance <= radius {
                nearbySegmentCount += 1
                
                // If more than one road segment is nearby, this is an intersection
                if nearbySegmentCount > 1 {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Simple Intersection Crossings - One Road Over Another
    
    internal func cleanupIntersectionOverlaps(playerPosition: SCNVector3) {
        let intersectionRadius: CGFloat = 30.0 // 30m radius for intersection detection (increased for better detection)
        
        // Get all loaded road segment positions
        var segmentPositions: [(String, SCNVector3, String)] = [] // segmentKey, position, routeType
        
        for (segmentKey, segmentNode) in loadedRoadSegments {
            let position = segmentNode.position
            
            // Determine route type from segment key
            let routeType: String
            if segmentKey.contains("paved_") {
                routeType = "paved"
            } else if segmentKey.contains("dirt_") {
                routeType = "dirt"  
            } else {
                routeType = "interstate"
            }
            
            segmentPositions.append((segmentKey, position, routeType))
        }
        
        // Find overlapping segments (intersections)
        var intersectionGroups: [[String]] = []
        var processedSegments: Set<String> = []
        
        for i in 0..<segmentPositions.count {
            if processedSegments.contains(segmentPositions[i].0) { continue }
            
            var intersectionGroup: [String] = [segmentPositions[i].0]
            processedSegments.insert(segmentPositions[i].0)
            
            // Find all segments that overlap with this one
            for j in (i+1)..<segmentPositions.count {
                if processedSegments.contains(segmentPositions[j].0) { continue }
                
                let distance = calculateDistance(from: segmentPositions[i].1, to: segmentPositions[j].1)
                if distance <= intersectionRadius {
                    intersectionGroup.append(segmentPositions[j].0)
                    processedSegments.insert(segmentPositions[j].0)
                }
            }
            
            // Only process groups with multiple segments (actual intersections)
            if intersectionGroup.count > 1 {
                intersectionGroups.append(intersectionGroup)
            }
        }
        
        // Clean up each intersection group
        for intersectionGroup in intersectionGroups {
            cleanupIntersectionGroup(segmentKeys: intersectionGroup, segmentPositions: segmentPositions)
        }
    }
    
    private func cleanupIntersectionGroup(segmentKeys: [String], segmentPositions: [(String, SCNVector3, String)]) {
        // SIMPLE SOLUTION: One road goes OVER the other by a tiny elevation
        
        // Determine road type priority: Interstate > Paved > Dirt
        let routeTypePriority: [String: Int] = [
            "interstate": 3,
            "paved": 2, 
            "dirt": 1
        ]
        
        // Find the highest priority road type in this intersection
        var highestPriority = 0
        var dominantRouteType = "dirt"
        
        for segmentKey in segmentKeys {
            if let segmentInfo = segmentPositions.first(where: { $0.0 == segmentKey }) {
                let priority = routeTypePriority[segmentInfo.2] ?? 0
                if priority > highestPriority {
                    highestPriority = priority
                    dominantRouteType = segmentInfo.2
                }
            }
        }
        
        // AGGRESSIVE INTERSECTION CLEANUP: Remove ALL markings from lower priority roads
        for segmentKey in segmentKeys {
            guard let segmentNode = loadedRoadSegments[segmentKey] else { continue }
            
            if let segmentInfo = segmentPositions.first(where: { $0.0 == segmentKey }) {
                let routeType = segmentInfo.2
                
                if routeType == dominantRouteType {
                    // Raise the dominant road by 2 inches (0.05 meters)
                    segmentNode.position.y = 0.05
                    print("🛣️ Elevated \(routeType) road over intersection")
                } else {
                    // Keep lower priority roads at ground level
                    segmentNode.position.y = 0.0
                    print("📍 Set \(routeType) road to ground level at intersection")
                }
            }
        }
    }
    

    
    private func loadRoadSegment(segmentKey: String, routeName: String) {
        // Look for route data in all route types
        var routeData: [(Double, Double)]?
        
        if routeName.hasPrefix("dirt_") {
            let cleanName = String(routeName.dropFirst(5)) // Remove "dirt_"
            routeData = dirtRoutes[cleanName]
        } else if routeName.hasPrefix("paved_") {
            let cleanName = String(routeName.dropFirst(6)) // Remove "paved_"
            routeData = pavedRoutes[cleanName]
        } else if routeName.hasPrefix("water_") {
            let cleanName = String(routeName.dropFirst(6)) // Remove "water_"
            routeData = waterBodies[cleanName]
        } else if routeName.hasPrefix("coast_") {
            let cleanName = String(routeName.dropFirst(6)) // Remove "coast_"
            routeData = coastlines[cleanName]
        } else {
            routeData = interstateRoutes[routeName]
        }
        
        guard let coords = routeData else { return }
        
        // FILTER OUT SHORT ROAD ARTIFACTS - Remove routes shorter than 5 miles
        let routeLength = calculateRouteLength(coords: coords)
        let FIVE_MILES_IN_METERS: Double = 8046.72 // 5 miles = 8,046.72 meters
        
        if routeLength < FIVE_MILES_IN_METERS {
            print("🗑️ Filtered out short road artifact: \(routeName) (\(Int(routeLength/1000))km)")
            return // Don't load this short artifact
        }
        
        // Generate smooth road points using existing Catmull-Rom spline system
        let smoothPoints = generateSmoothRoadPoints(from: coords)
        
        // Create longer curved road segments instead of individual straight segments
        let segmentLength = 500 // Points per segment for smooth curves
        let components = segmentKey.split(separator: "_")
        guard let segmentIndex = Int(components.last!) else { return }
        
        let startIndex = segmentIndex * segmentLength
        guard startIndex < smoothPoints.count - 1 else { return }
        
        let endIndex = min(startIndex + segmentLength, smoothPoints.count - 1)
        let segmentPoints = Array(smoothPoints[startIndex...endIndex])
        
        // Determine route type and create appropriate road segment
        let roadNode: SCNNode
        if routeName.hasPrefix("dirt_") {
            roadNode = createDirtRoadSegmentNode(points: segmentPoints, routeName: routeName)
            print("🛤️ Loading dirt road segment: \(segmentKey)")
        } else if routeName.hasPrefix("paved_") {
            roadNode = createPavedRoadSegmentNode(points: segmentPoints, routeName: routeName)
            print("🛣️ Loading paved road segment: \(segmentKey)")
        } else if routeName.hasPrefix("water_") {
            roadNode = createWaterBodySegmentNode(points: segmentPoints, routeName: routeName)
            print("🌊 Loading water segment: \(segmentKey)")
        } else if routeName.hasPrefix("coast_") {
            roadNode = createCoastlineSegmentNode(points: segmentPoints, routeName: routeName)
            print("🏖️ Loading coastline segment: \(segmentKey)")
        } else {
            roadNode = createSmoothRoadSegmentNode(points: segmentPoints, routeName: routeName)
            print("🛣️ Loading interstate road segment: \(segmentKey)")
        }
        
        // Add to scene and tracking
        roadSystemNode.addChildNode(roadNode)
        loadedRoadSegments[segmentKey] = roadNode
    }
    
    private func unloadRoadSegment(segmentKey: String) {
        guard let roadNode = loadedRoadSegments[segmentKey] else { return }
        
        roadNode.removeFromParentNode()
        loadedRoadSegments.removeValue(forKey: segmentKey)
    }
    
    private func updateSegmentHUD(maxSegments: Int) {
        let count = loadedRoadSegments.count
        let status = count >= maxSegments ? "⚠️MAX" : ""
        
        DispatchQueue.main.async {
            self.segmentCountLabel?.stringValue = "\(count)/\(maxSegments) segments \(status)"
        }
    }
    
    // MARK: - Road Creation Functions for Different Types
    
    private func createPavedRoadSegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Create curved road segments with light gray paved material
        guard points.count >= 2 else { return roadNode }
        
        // Create individual road pieces along the curve
        for i in 0..<points.count - 1 {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let startPos = SCNVector3(startPoint.0, 0, startPoint.1)
            let endPos = SCNVector3(endPoint.0, 0, endPoint.1)
            
            let roadPiece = createPavedRoadPiece(from: startPos, to: endPos, routeName: routeName)
            roadNode.addChildNode(roadPiece)
        }
        
        // Add road markings for paved roads
        createPavedRoadMarkings(roadNode: roadNode, points: points, routeName: routeName)
        
        return roadNode
    }
    
    private func createPavedRoadPiece(from startPos: SCNVector3, to endPos: SCNVector3, routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Calculate road properties
        let deltaX = endPos.x - startPos.x
        let deltaZ = endPos.z - startPos.z
        let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
        
        // Create main road surface
        let roadGeometry = SCNBox(width: 20.0, height: 0.1, length: CGFloat(distance) + 0.5, chamferRadius: 0)
        
        // Light gray paved road material
        let pavedMaterial = SCNMaterial()
        pavedMaterial.diffuse.contents = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) // Light gray
        pavedMaterial.emission.contents = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        pavedMaterial.roughness.contents = 0.6
        pavedMaterial.metalness.contents = 0.1
        roadGeometry.materials = [pavedMaterial]
        
        // Create road surface node
        let roadSegmentNode = SCNNode(geometry: roadGeometry)
        
        // Position and orient the road
        let midPoint = SCNVector3(
            (startPos.x + endPos.x) / 2,
            0.0,
            (startPos.z + endPos.z) / 2
        )
        
        roadSegmentNode.position = midPoint
        
        if distance > 0 {
            let angle = atan2(deltaX, deltaZ)
            roadSegmentNode.rotation = SCNVector4(0, 1, 0, CGFloat(angle))
        }
        
        roadNode.addChildNode(roadSegmentNode)
        return roadNode
    }
    
    private func createPavedRoadMarkings(roadNode: SCNNode, points: [(CGFloat, CGFloat)], routeName: String) {
        // Create standard white lines for paved roads
        createStandardRoadMarkings(roadNode: roadNode, points: points, centerColor: .white, edgeColor: .white)
    }
    
    private func createStandardRoadMarkings(roadNode: SCNNode, points: [(CGFloat, CGFloat)], centerColor: NSColor, edgeColor: NSColor) {
        guard points.count >= 10 else { return }
        
        // Create edge lines
        let edgeOffsets: [CGFloat] = [-10.0, 10.0] // Left and right edges
        
        for offset in edgeOffsets {
            // Calculate smooth normals for the entire curve
            var normals: [(CGFloat, CGFloat)] = []
            
            for i in 0..<points.count {
                let normal: (CGFloat, CGFloat)
                
                if i == 0 && points.count > 1 {
                    let dx = points[1].0 - points[0].0
                    let dz = points[1].1 - points[0].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len)
                } else if i == points.count - 1 && i > 0 {
                    let dx = points[i].0 - points[i-1].0
                    let dz = points[i].1 - points[i-1].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len)
                } else if i > 0 && i < points.count - 1 {
                    let dx = points[i+1].0 - points[i-1].0
                    let dz = points[i+1].1 - points[i-1].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len)
                } else {
                    normal = (1, 0)
                }
                
                normals.append(normal)
            }
            
            // Create edge points using smooth normals
            var edgePoints: [SCNVector3] = []
            for i in 0..<points.count {
                let point = points[i]
                let normal = normals[i]
                
                let edgeX = point.0 + offset * normal.0
                let edgeZ = point.1 + offset * normal.1
                edgePoints.append(SCNVector3(edgeX, 0.15, edgeZ))
            }
            
            // Create a continuous curved line from the edge points
            createContinuousCurvedLine(points: edgePoints, color: edgeColor, width: 0.5, parent: roadNode)
        }
        
        // Create center dashed line
        var centerPoints: [SCNVector3] = []
        for point in points {
            centerPoints.append(SCNVector3(point.0, 0.15, point.1))
        }
        
        createDashedCurvedLine(points: centerPoints, color: centerColor, width: 0.5, 
                              dashLength: 10.0, gapLength: 15.0, parent: roadNode)
    }
    
    private func createDirtRoadSegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Create curved road segments with orange dirt material
        guard points.count >= 2 else { return roadNode }
        
        // Create individual road pieces along the curve
        for i in 0..<points.count - 1 {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let startPos = SCNVector3(startPoint.0, 0, startPoint.1)
            let endPos = SCNVector3(endPoint.0, 0, endPoint.1)
            
            let roadPiece = createDirtRoadPiece(from: startPos, to: endPos, routeName: routeName)
            roadNode.addChildNode(roadPiece)
        }
        
        // Add road markings for dirt roads (minimal markings)
        createDirtRoadMarkings(roadNode: roadNode, points: points, routeName: routeName)
        
        return roadNode
    }
    
    private func createDirtRoadPiece(from startPos: SCNVector3, to endPos: SCNVector3, routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Calculate road properties
        let deltaX = endPos.x - startPos.x
        let deltaZ = endPos.z - startPos.z
        let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
        
        // Create main road surface
        let roadGeometry = SCNBox(width: 18.0, height: 0.05, length: CGFloat(distance) + 0.5, chamferRadius: 0)
        
        // Orange dirt road material
        let dirtMaterial = SCNMaterial()
        dirtMaterial.diffuse.contents = NSColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0) // Orange dirt
        dirtMaterial.emission.contents = NSColor(red: 0.05, green: 0.02, blue: 0.01, alpha: 1.0)
        dirtMaterial.roughness.contents = 0.8 // Very rough for dirt
        dirtMaterial.metalness.contents = 0.0 // No metallic for dirt
        roadGeometry.materials = [dirtMaterial]
        
        // Create road surface node
        let roadSegmentNode = SCNNode(geometry: roadGeometry)
        
        // Position and orient the road
        let midPoint = SCNVector3(
            (startPos.x + endPos.x) / 2,
            -0.05, // Slightly lower than paved roads
            (startPos.z + endPos.z) / 2
        )
        
        roadSegmentNode.position = midPoint
        
        if distance > 0 {
            let angle = atan2(deltaX, deltaZ)
            roadSegmentNode.rotation = SCNVector4(0, 1, 0, CGFloat(angle))
        }
        
        roadNode.addChildNode(roadSegmentNode)
        return roadNode
    }
    
    private func createDirtRoadMarkings(roadNode: SCNNode, points: [(CGFloat, CGFloat)], routeName: String) {
        // Dirt roads have minimal markings - just faded edge lines, no center line
        createMinimalRoadMarkings(roadNode: roadNode, points: points, edgeColor: NSColor(red: 0.6, green: 0.3, blue: 0.15, alpha: 0.6))
    }
    
    private func createMinimalRoadMarkings(roadNode: SCNNode, points: [(CGFloat, CGFloat)], edgeColor: NSColor) {
        guard points.count >= 10 else { return }
        
        // Create only edge lines for dirt roads
        let edgeOffsets: [CGFloat] = [-9.0, 9.0] // Slightly narrower for dirt roads
        
        for offset in edgeOffsets {
            // Calculate smooth normals for the entire curve
            var normals: [(CGFloat, CGFloat)] = []
            
            for i in 0..<points.count {
                let normal: (CGFloat, CGFloat)
                
                if i == 0 && points.count > 1 {
                    let dx = points[1].0 - points[0].0
                    let dz = points[1].1 - points[0].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len)
                } else if i == points.count - 1 && i > 0 {
                    let dx = points[i].0 - points[i-1].0
                    let dz = points[i].1 - points[i-1].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len)
                } else if i > 0 && i < points.count - 1 {
                    let dx = points[i+1].0 - points[i-1].0
                    let dz = points[i+1].1 - points[i-1].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len)
                } else {
                    normal = (1, 0)
                }
                
                normals.append(normal)
            }
            
            // Create edge points using smooth normals
            var edgePoints: [SCNVector3] = []
            for i in 0..<points.count {
                let point = points[i]
                let normal = normals[i]
                
                let edgeX = point.0 + offset * normal.0
                let edgeZ = point.1 + offset * normal.1
                edgePoints.append(SCNVector3(edgeX, 0.10, edgeZ)) // Lower than paved roads
            }
            
            // Create faded edge lines for dirt roads
            createContinuousCurvedLine(points: edgePoints, color: edgeColor, width: 0.3, parent: roadNode)
        }
        
        // No center line for dirt roads
    }
    
    // MARK: - Water Feature Creation Functions
    
    private func createWaterBodySegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
        let waterNode = SCNNode()
        
        // Create curved water segments with blue material
        guard points.count >= 2 else { return waterNode }
        
        // Create individual water pieces along the curve
        for i in 0..<points.count - 1 {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let startPos = SCNVector3(startPoint.0, 0, startPoint.1)
            let endPos = SCNVector3(endPoint.0, 0, endPoint.1)
            
            let waterPiece = createWaterPiece(from: startPos, to: endPos, routeName: routeName, isRiver: true)
            waterNode.addChildNode(waterPiece)
        }
        
        return waterNode
    }
    
    private func createCoastlineSegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
        let coastNode = SCNNode()
        
        // Create curved coastline segments with blue-green material
        guard points.count >= 2 else { return coastNode }
        
        // Create individual coastline pieces along the curve
        for i in 0..<points.count - 1 {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let startPos = SCNVector3(startPoint.0, 0, startPoint.1)
            let endPos = SCNVector3(endPoint.0, 0, endPoint.1)
            
            let coastPiece = createWaterPiece(from: startPos, to: endPos, routeName: routeName, isRiver: false)
            coastNode.addChildNode(coastPiece)
        }
        
        return coastNode
    }
    
    private func createWaterPiece(from startPos: SCNVector3, to endPos: SCNVector3, routeName: String, isRiver: Bool) -> SCNNode {
        let waterNode = SCNNode()
        
        // Calculate water properties
        let deltaX = endPos.x - startPos.x
        let deltaZ = endPos.z - startPos.z
        let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
        
        // Create main water surface
        let width: CGFloat = isRiver ? 15.0 : 25.0 // Rivers narrower than coastlines
        let waterGeometry = SCNBox(width: width, height: 0.02, length: CGFloat(distance) + 0.5, chamferRadius: 0)
        
        // Water material with transparency and reflection
        let waterMaterial = SCNMaterial()
        if isRiver {
            waterMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.7) // River blue
        } else {
            waterMaterial.diffuse.contents = NSColor(red: 0.1, green: 0.4, blue: 0.6, alpha: 0.8) // Ocean blue-green
        }
        waterMaterial.emission.contents = NSColor(red: 0.0, green: 0.1, blue: 0.2, alpha: 0.3)
        waterMaterial.roughness.contents = 0.1 // Very smooth for water reflection
        waterMaterial.metalness.contents = 0.9 // Highly reflective
        waterMaterial.transparency = 0.8 // Semi-transparent
        waterGeometry.materials = [waterMaterial]
        
        // Create water surface node
        let waterSegmentNode = SCNNode(geometry: waterGeometry)
        
        // Position and orient the water
        let midPoint = SCNVector3(
            (startPos.x + endPos.x) / 2,
            -0.1, // Slightly below ground level
            (startPos.z + endPos.z) / 2
        )
        
        waterSegmentNode.position = midPoint
        
        if distance > 0 {
            let angle = atan2(deltaX, deltaZ)
            waterSegmentNode.rotation = SCNVector4(0, 1, 0, CGFloat(angle))
        }
        
        waterNode.addChildNode(waterSegmentNode)
        return waterNode
    }
    
    // MARK: - Smooth Curved Road Creation WITH PROPER MARKINGS
    func createSmoothRoadSegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Create curved road segments with proper markings
        guard points.count >= 2 else { return roadNode }
        
        // Create individual road pieces along the curve
        for i in 0..<points.count - 1 {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let startPos = SCNVector3(startPoint.0, 0, startPoint.1)
            let endPos = SCNVector3(endPoint.0, 0, endPoint.1)
            
            let roadPiece = createRoadPiece(from: startPos, to: endPos, routeName: routeName)
            roadNode.addChildNode(roadPiece)
        }
        
        // Add consistent markings along the entire curve (unless at intersection)
        if !isAtIntersectionWithHigherPriorityRoad(routeName: routeName, points: points) {
            createSmoothRoadMarkings(roadNode: roadNode, points: points, routeName: routeName)
        } else {
            print("🚫 Skipped markings for \(routeName) - at intersection with higher priority road")
        }
        
        return roadNode
    }
    
    // MARK: - Road Node Creation WITH PROPER MARKINGS
    private func createRoadPiece(from startPos: SCNVector3, to endPos: SCNVector3, routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Calculate road properties
        let deltaX = endPos.x - startPos.x
        let deltaZ = endPos.z - startPos.z
        let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
        
        // Create main road surface - ADD EXTRA LENGTH TO PREVENT GAPS
        let roadGeometry = SCNBox(width: 20.0, height: 0.1, length: CGFloat(distance) + 0.5, chamferRadius: 0)
        
        // Road surface material
        let roadMaterial = SCNMaterial()
        if routeName.contains("I-") {
            roadMaterial.diffuse.contents = NSColor.darkGray
        } else {
            roadMaterial.diffuse.contents = NSColor.gray
        }
        roadGeometry.materials = [roadMaterial]
        
        // Create road surface node
        let roadSegmentNode = SCNNode(geometry: roadGeometry)
        
        // Position and orient the road
        let midPoint = SCNVector3(
            (startPos.x + endPos.x) / 2,
            0.0,
            (startPos.z + endPos.z) / 2
        )
        
        roadSegmentNode.position = midPoint
        
        if distance > 0 {
            let angle = atan2(deltaX, deltaZ)
            roadSegmentNode.rotation = SCNVector4(0, 1, 0, angle)
        }
        
        roadNode.addChildNode(roadSegmentNode)
        return roadNode
    }
    
    // MARK: - Correct Highway Road Markings
    private func createSmoothRoadMarkings(roadNode: SCNNode, points: [(CGFloat, CGFloat)], routeName: String) {
        guard points.count >= 10 else { return }
        
        // CORRECT HIGHWAY MARKINGS FROM MUTCD STANDARDS:
        // 1. SOLID WHITE LINES on left and right EDGES where road meets grass
        // 2. SHORT YELLOW DASHED LINE in the CENTER of the road
        
        createSmoothCurvedEdgeLines(roadNode: roadNode, points: points)
        createSmoothCurvedCenterDashes(roadNode: roadNode, points: points)
    }
    
    // MARK: - Smooth Curved Road Markings Using Paths
    
    private func createSmoothCurvedEdgeLines(roadNode: SCNNode, points: [(CGFloat, CGFloat)]) {
        // Create CONTINUOUS CURVED white edge lines with SMOOTH offsets
        let edgeOffsets: [CGFloat] = [-10.0, 10.0] // Left and right edges
        
        for offset in edgeOffsets {
            // Calculate smooth normals for the entire curve
            var normals: [(CGFloat, CGFloat)] = []
            
            for i in 0..<points.count {
                let normal: (CGFloat, CGFloat)
                
                if i == 0 && points.count > 1 {
                    // First point - use direction to next
                    let dx = points[1].0 - points[0].0
                    let dz = points[1].1 - points[0].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len) // Perpendicular
                } else if i == points.count - 1 && i > 0 {
                    // Last point - use direction from previous
                    let dx = points[i].0 - points[i-1].0
                    let dz = points[i].1 - points[i-1].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len) // Perpendicular
                } else if i > 0 && i < points.count - 1 {
                    // Middle points - use central difference for smoother curves
                    let dx = points[i+1].0 - points[i-1].0
                    let dz = points[i+1].1 - points[i-1].1
                    let len = sqrt(dx*dx + dz*dz)
                    normal = (-dz/len, dx/len) // Perpendicular
                } else {
                    normal = (1, 0)
                }
                
                normals.append(normal)
            }
            
            // Create edge points using smooth normals
            var edgePoints: [SCNVector3] = []
            for i in 0..<points.count {
                let point = points[i]
                let normal = normals[i]
                
                let edgeX = point.0 + offset * normal.0
                let edgeZ = point.1 + offset * normal.1
                edgePoints.append(SCNVector3(edgeX, 0.15, edgeZ))
            }
            
            // Create a continuous curved line from the edge points
            createContinuousCurvedLine(points: edgePoints, color: .white, width: 0.5, parent: roadNode)
        }
    }
    
    private func createSmoothCurvedCenterDashes(roadNode: SCNNode, points: [(CGFloat, CGFloat)]) {
        // Create SHORT YELLOW DASHES along the center curve
        var centerPoints: [SCNVector3] = []
        
        // Convert road points to center line (no offset needed for center)
        for point in points {
            centerPoints.append(SCNVector3(point.0, 0.15, point.1))
        }
        
        // Create dashed yellow center line
        createDashedCurvedLine(points: centerPoints, color: .yellow, width: 0.5, 
                              dashLength: 10.0, gapLength: 15.0, parent: roadNode)
    }
    
    // MARK: - Curve Creation Helpers
    
    private func createContinuousCurvedLine(points: [SCNVector3], color: NSColor, width: CGFloat, parent: SCNNode) {
        // INTERSECTION FIX: Stop markings at intersection points
        let intersectionRadius: CGFloat = 25.0
        
        // Create segments between consecutive points, but skip intersection areas
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]
            
            // Check if this segment is near an intersection
            if isPointNearIntersection(start, radius: intersectionRadius) || 
               isPointNearIntersection(end, radius: intersectionRadius) {
                // Skip creating markings in intersection areas
                continue
            }
            
            let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
            guard distance > 0.1 else { continue }
            
            // Create line segment
            let lineGeometry = SCNBox(width: width, height: 0.05, length: distance, chamferRadius: 0)
            let material = SCNMaterial()
            
            // Use full opacity - will be updated in real-time by game loop
            material.diffuse.contents = color
            material.emission.contents = color.withAlphaComponent(0.3)
            
            // Apply blur to prevent distant moiré patterns
            material.diffuse.magnificationFilter = .linear
            material.diffuse.minificationFilter = .linear
            material.diffuse.mipFilter = .linear
            
            // Add material blur for distant road markings
            material.roughness.contents = 0.8  // Increase roughness for blur effect
            material.metalness.contents = 0.0  // Remove metallic sheen
            material.emission.intensity = 0.5  // Reduce emission intensity
            
            lineGeometry.materials = [material]
            
            let lineNode = SCNNode(geometry: lineGeometry)
            
            // Position at midpoint
            lineNode.position = SCNVector3(
                (start.x + end.x) / 2,
                (start.y + end.y) / 2,
                (start.z + end.z) / 2
            )
            
            // Rotate to align with direction
            let angle = atan2(end.x - start.x, end.z - start.z)
            lineNode.rotation = SCNVector4(0, 1, 0, angle)
            
            parent.addChildNode(lineNode)
        }
    }
    
    private func createDashedCurvedLine(points: [SCNVector3], color: NSColor, width: CGFloat, 
                                       dashLength: CGFloat, gapLength: CGFloat, parent: SCNNode) {
        // Track distance along curve
        var accumulatedDistance: CGFloat = 0
        var currentlyDrawing = true
        var dashStartIndex = 0
        var dashStartT: CGFloat = 0
        
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]
            let segmentLength = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
            
            var segmentProgress: CGFloat = 0
            
            while segmentProgress < segmentLength {
                let remainingInSegment = segmentLength - segmentProgress
                let targetLength = currentlyDrawing ? dashLength : gapLength
                let remainingInDashOrGap = targetLength - (accumulatedDistance.truncatingRemainder(dividingBy: dashLength + gapLength)).truncatingRemainder(dividingBy: targetLength)
                
                let advanceLength = min(remainingInSegment, remainingInDashOrGap)
                
                if currentlyDrawing {
                    // Calculate dash endpoints
                    let t1 = segmentProgress / segmentLength
                    let t2 = (segmentProgress + advanceLength) / segmentLength
                    
                    let dashStart = SCNVector3(
                        start.x + (end.x - start.x) * t1,
                        start.y + (end.y - start.y) * t1,
                        start.z + (end.z - start.z) * t1
                    )
                    
                    let dashEnd = SCNVector3(
                        start.x + (end.x - start.x) * t2,
                        start.y + (end.y - start.y) * t2,
                        start.z + (end.z - start.z) * t2
                    )
                    
                    // Check if this dash is near an intersection - skip if so
                    if isPointNearIntersection(dashStart, radius: 25.0) || 
                       isPointNearIntersection(dashEnd, radius: 25.0) {
                        // Skip creating this dash in intersection area
                    } else {
                        // Create dash
                        let dashDist = sqrt(pow(dashEnd.x - dashStart.x, 2) + pow(dashEnd.z - dashStart.z, 2))
                        if dashDist > 0.1 {
                        let dashGeometry = SCNBox(width: width, height: 0.05, length: dashDist, chamferRadius: 0)
                        let material = SCNMaterial()
                        
                        // Use full opacity - will be updated in real-time by game loop
                        material.diffuse.contents = color
                        material.emission.contents = color.withAlphaComponent(0.4)
                        
                        // Apply blur to prevent distant moiré patterns
                        material.diffuse.magnificationFilter = .linear
                        material.diffuse.minificationFilter = .linear
                        material.diffuse.mipFilter = .linear
                        
                        // Add material blur for distant road markings
                        material.roughness.contents = 0.8  // Increase roughness for blur effect
                        material.metalness.contents = 0.0  // Remove metallic sheen
                        material.emission.intensity = 0.5  // Reduce emission intensity
                        
                        dashGeometry.materials = [material]
                        
                        let dashNode = SCNNode(geometry: dashGeometry)
                        dashNode.position = SCNVector3(
                            (dashStart.x + dashEnd.x) / 2,
                            (dashStart.y + dashEnd.y) / 2,
                            (dashStart.z + dashEnd.z) / 2
                        )
                        
                        // Rotate to align with direction
                        let angle = atan2(dashEnd.x - dashStart.x, dashEnd.z - dashStart.z)
                        dashNode.rotation = SCNVector4(0, 1, 0, angle)
                        
                            parent.addChildNode(dashNode)
                        }
                    }
                }
                
                segmentProgress += advanceLength
                accumulatedDistance += advanceLength
                
                // Check if we should switch between dash and gap
                let cycleProgress = accumulatedDistance.truncatingRemainder(dividingBy: dashLength + gapLength)
                currentlyDrawing = cycleProgress < dashLength
            }
        }
    }
}
