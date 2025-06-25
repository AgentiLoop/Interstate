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
        
        // USER REQUIREMENTS - STRICT LIMITS to prevent memory explosion and stalls
        let SEGMENT_LOAD_DISTANCE: CGFloat = 2000.0    // Increased to ensure roads are found
        let SEGMENT_UNLOAD_DISTANCE: CGFloat = 3000.0  // Increased accordingly
        let MAX_SEGMENTS: Int = 350                   // USER'S REQUIRED LIMIT - never exceed!
        let MIN_SEGMENTS: Int = 100                   // Reasonable minimum
        
        // STALL PREVENTION - Only update every 8 frames to prevent constant loading
        // BUT: Always update on first few frames when no roads are loaded
        roadUpdateCounter += 1
        if roadUpdateCounter % 8 != 0 && loadedRoadSegments.count > 10 { return }
        
        let playerPosition = playerNode.position
        
        // FLOATING POINT PRECISION FIX - World origin rebasing for large coordinates
        checkAndRebaseWorldOrigin(playerPosition: playerPosition)
        
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
        // FALLBACK: Use interstateRoutes if routeGPSData is empty
        let routesToUse = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        if routesToUse.isEmpty {
            return
        }
        
        // Find the closest route to the player using the available route data
        guard let closestRoute = findClosestRouteIn(routes: routesToUse, to: playerPosition) else { 
            return 
        }
        
        // Get the route data
        guard let routeData = routesToUse[closestRoute] else { 
            return 
        }
        
        // Load segments from this route that are close enough
        var segmentsToLoad: [(String, CGFloat)] = []
        
        for (index, (lat, lon)) in routeData.enumerated() {
            let segmentKey = "\(closestRoute)_\(index)"
            
            // Skip if already loaded
            if loadedRoadSegments[segmentKey] != nil { continue }
            
            let segmentPosition = gpsToSceneKit(latitude: lat, longitude: lon)
            let distance = calculateDistance(from: playerPosition, to: segmentPosition)
            
            if distance <= loadDistance {
                segmentsToLoad.append((segmentKey, distance))
            }
        }
        
        // Sort by distance (closest first)
        segmentsToLoad.sort { $0.1 < $1.1 }
        
        // Load segments until we hit the limit
        for (segmentKey, _) in segmentsToLoad {
            if loadedRoadSegments.count >= maxSegments { break }
            loadRoadSegment(segmentKey: segmentKey, routeName: closestRoute)
        }
    }
    
    // MARK: - World Origin Rebasing (Floating Point Precision Fix)
    
    private func checkAndRebaseWorldOrigin(playerPosition: SCNVector3) {
        // FLOATING POINT PRECISION: When coordinates get too large, precision is lost
        // causing jitter, stalls, and rendering problems. Rebase when player is far from origin.
        
        let REBASE_THRESHOLD: CGFloat = 5000.0 // When player is 5km from origin
        let REBASE_DISTANCE: CGFloat = 3000.0  // How far they've moved since last rebase
        
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
    private func calculateDistance(from point1: SCNVector3, to point2: SCNVector3) -> CGFloat {
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
    
    private func calculateSegmentDistance(segmentKey: String, playerPosition: SCNVector3) -> CGFloat {
        // Extract route name and index from segment key
        let components = segmentKey.split(separator: "_")
        guard components.count >= 2,
              let index = Int(components.last!) else { return CGFloat.infinity }
        
        let routeName = components.dropLast().joined(separator: "_")
        
        // Use fallback route source if needed
        let routesToUse = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        guard let routeData = routesToUse[routeName],
              index < routeData.count else { return CGFloat.infinity }
        
        let (lat, lon) = routeData[index]
        let segmentPosition = gpsToSceneKit(latitude: lat, longitude: lon)
        
        return calculateDistance(from: playerPosition, to: segmentPosition)
    }
    
    private func loadRoadSegment(segmentKey: String, routeName: String) {
        // Extract index from segment key
        let components = segmentKey.split(separator: "_")
        guard let index = Int(components.last!) else { return }
        
        // Use fallback route source if needed
        let routesToUse = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        guard let routeData = routesToUse[routeName],
              index < routeData.count - 1 else { return }
        
        // Create road segment
        let startPoint = routeData[index]
        let endPoint = routeData[index + 1]
        
        let startPos = gpsToSceneKit(latitude: startPoint.0, longitude: startPoint.1)
        let endPos = gpsToSceneKit(latitude: endPoint.0, longitude: endPoint.1)
        
        let roadNode = createRoadSegmentNode(from: startPos, to: endPos, routeName: routeName)
        
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
    
    // MARK: - Road Node Creation WITH PROPER MARKINGS
    private func createRoadSegmentNode(from startPos: SCNVector3, to endPos: SCNVector3, routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Calculate road properties
        let deltaX = endPos.x - startPos.x
        let deltaZ = endPos.z - startPos.z
        let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
        
        // Create main road surface
        let roadGeometry = SCNBox(width: 20.0, height: 0.1, length: CGFloat(distance), chamferRadius: 0)
        
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
            roadSegmentNode.rotation = SCNVector4(0, 1, 0, Float(angle))
            
            // Add road markings
            createHighwayCenterLine(roadNode: roadNode, startPos: startPos, endPos: endPos, angle: angle)
            createHighwayEdgeLines(roadNode: roadNode, startPos: startPos, endPos: endPos, angle: angle)
            createHighwayLaneMarkings(roadNode: roadNode, startPos: startPos, endPos: endPos, angle: angle)
        }
        
        roadNode.addChildNode(roadSegmentNode)
        return roadNode
    }
    
    // MARK: - Highway Markings
    private func createHighwayCenterLine(roadNode: SCNNode, startPos: SCNVector3, endPos: SCNVector3, angle: CGFloat) {
        let distance = calculateDistance(from: startPos, to: endPos)
        
        // Yellow center line material  
        let centerMaterial = SCNMaterial()
        centerMaterial.diffuse.contents = NSColor.yellow
        centerMaterial.emission.contents = NSColor.yellow.withAlphaComponent(0.3)
        
        // Create dashed center line
        let dashLength: CGFloat = 10.0
        let gapLength: CGFloat = 5.0
        var currentDistance: CGFloat = 0.0
        
        while currentDistance + dashLength < distance - 2.0 {
            let ratio = CGFloat(currentDistance) / CGFloat(distance)
            
            // Calculate position step by step to avoid complex expressions
            let deltaX = endPos.x - startPos.x
            let deltaZ = endPos.z - startPos.z
            let posX = startPos.x + deltaX * ratio
            let posZ = startPos.z + deltaZ * ratio
            let dashPosition = SCNVector3(posX, 0.15, posZ)
            
            let centerDash = SCNBox(width: 0.5, height: 0.05, length: dashLength, chamferRadius: 0)
            centerDash.materials = [centerMaterial]
            
            let dashNode = SCNNode(geometry: centerDash)
            dashNode.position = dashPosition
            dashNode.rotation = SCNVector4(0, 1, 0, Float(angle))
            
            roadNode.addChildNode(dashNode)
            
            currentDistance += dashLength + gapLength
        }
    }
    
    private func createHighwayEdgeLines(roadNode: SCNNode, startPos: SCNVector3, endPos: SCNVector3, angle: CGFloat) {
        let distance = calculateDistance(from: startPos, to: endPos)
        
        // White edge line material
        let edgeMaterial = SCNMaterial()
        edgeMaterial.diffuse.contents = NSColor.white
        edgeMaterial.emission.contents = NSColor.white.withAlphaComponent(0.2)
        
        // Create edge lines at ±10 units (for 20 unit wide road)
        let edgeOffsets: [CGFloat] = [-10.0, 10.0]
        
        for offset in edgeOffsets {
            // Calculate edge position step by step
            let perpendicularAngle = angle + CGFloat.pi/2
            let offsetX = offset * cos(perpendicularAngle)
            let offsetZ = offset * sin(perpendicularAngle)
            let edgeStartPos = SCNVector3(startPos.x + offsetX, 0.15, startPos.z + offsetZ)
            
            let edgeLine = SCNBox(width: 0.3, height: 0.05, length: CGFloat(distance), chamferRadius: 0)
            edgeLine.materials = [edgeMaterial]
            
            let edgeNode = SCNNode(geometry: edgeLine)
            
            // Calculate edge line center position step by step
            let midX = (startPos.x + endPos.x) / 2
            let midZ = (startPos.z + endPos.z) / 2
            let finalX = midX + offsetX
            let finalZ = midZ + offsetZ
            edgeNode.position = SCNVector3(finalX, 0.15, finalZ)
            edgeNode.rotation = SCNVector4(0, 1, 0, Float(angle))
            
            roadNode.addChildNode(edgeNode)
        }
    }
    
    private func createHighwayLaneMarkings(roadNode: SCNNode, startPos: SCNVector3, endPos: SCNVector3, angle: CGFloat) {
        let distance = calculateDistance(from: startPos, to: endPos)
        
        // White lane marking material
        let laneMaterial = SCNMaterial()
        laneMaterial.diffuse.contents = NSColor.white
        laneMaterial.emission.contents = NSColor.white.withAlphaComponent(0.2)
        
        // Create lane markings at ±5 units (dividing the 20-unit road into 4 lanes)
        let laneOffsets: [CGFloat] = [-5.0, 5.0]
        
        for offset in laneOffsets {
            // Create dashed lane markings
            let dashLength: CGFloat = 6.0
            let gapLength: CGFloat = 4.0
            var currentDistance: CGFloat = 0.0
            
            while currentDistance + dashLength < distance - 2.0 {
                let ratio = CGFloat(currentDistance) / CGFloat(distance)
                
                // Calculate lane marking position step by step to avoid complex expressions
                let perpendicularAngle = angle + CGFloat.pi/2
                let deltaX = endPos.x - startPos.x
                let deltaZ = endPos.z - startPos.z
                let baseX = startPos.x + deltaX * ratio
                let baseZ = startPos.z + deltaZ * ratio
                let offsetX = offset * cos(perpendicularAngle)
                let offsetZ = offset * sin(perpendicularAngle)
                let dashPosition = SCNVector3(baseX + offsetX, 0.15, baseZ + offsetZ)
                
                let laneDash = SCNBox(width: 0.3, height: 0.05, length: dashLength, chamferRadius: 0)
                laneDash.materials = [laneMaterial]
                
                let dashNode = SCNNode(geometry: laneDash)
                dashNode.position = dashPosition
                dashNode.rotation = SCNVector4(0, 1, 0, Float(angle))
                
                roadNode.addChildNode(dashNode)
                
                currentDistance += dashLength + gapLength
            }
        }
    }
}
