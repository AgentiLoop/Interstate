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
        
        // Get the route data and generate smooth points
        guard let routeData = routesToUse[closestRoute] else { 
            return 
        }
        
        let smoothPoints = generateSmoothRoadPoints(from: routeData)
        let segmentLength = 500 // Points per smooth curve segment
        let totalSegments = (smoothPoints.count + segmentLength - 1) / segmentLength
        
        // Load curve segments that are close enough
        var segmentsToLoad: [(String, CGFloat)] = []
        
        for segmentIndex in 0..<totalSegments {
            let segmentKey = "\(closestRoute)_\(segmentIndex)"
            
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
        // Extract route name and segment index from segment key
        let components = segmentKey.split(separator: "_")
        guard components.count >= 2,
              let segmentIndex = Int(components.last!) else { return CGFloat.infinity }
        
        let routeName = components.dropLast().joined(separator: "_")
        
        // Use fallback route source if needed
        let routesToUse = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        guard let routeData = routesToUse[routeName] else { return CGFloat.infinity }
        
        // Generate smooth points and find closest point in this segment
        let smoothPoints = generateSmoothRoadPoints(from: routeData)
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
    
    private func loadRoadSegment(segmentKey: String, routeName: String) {
        // Extract route name and create smooth curve segment
        // Use fallback route source if needed
        let routesToUse = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        guard let routeData = routesToUse[routeName] else { return }
        
        // Generate smooth road points using existing Catmull-Rom spline system
        let smoothPoints = generateSmoothRoadPoints(from: routeData)
        
        // Create longer curved road segments instead of individual straight segments
        let segmentLength = 500 // Points per segment for smooth curves
        let components = segmentKey.split(separator: "_")
        guard let segmentIndex = Int(components.last!) else { return }
        
        let startIndex = segmentIndex * segmentLength
        guard startIndex < smoothPoints.count - 1 else { return }
        
        let endIndex = min(startIndex + segmentLength, smoothPoints.count - 1)
        let segmentPoints = Array(smoothPoints[startIndex...endIndex])
        
        let roadNode = createSmoothRoadSegmentNode(points: segmentPoints, routeName: routeName)
        
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
    
    // MARK: - Smooth Curved Road Creation WITH PROPER MARKINGS
    private func createSmoothRoadSegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
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
        
        // Add consistent markings along the entire curve
        createSmoothRoadMarkings(roadNode: roadNode, points: points, routeName: routeName)
        
        return roadNode
    }
    
    // MARK: - Road Node Creation WITH PROPER MARKINGS
    private func createRoadPiece(from startPos: SCNVector3, to endPos: SCNVector3, routeName: String) -> SCNNode {
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
        // Create segments between consecutive points
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]
            
            let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
            guard distance > 0.1 else { continue }
            
            // Create line segment
            let lineGeometry = SCNBox(width: width, height: 0.05, length: distance, chamferRadius: 0)
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color.withAlphaComponent(0.3)
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
            lineNode.rotation = SCNVector4(0, 1, 0, Float(angle))
            
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
                    
                    // Create dash
                    let dashDist = sqrt(pow(dashEnd.x - dashStart.x, 2) + pow(dashEnd.z - dashStart.z, 2))
                    if dashDist > 0.1 {
                        let dashGeometry = SCNBox(width: width, height: 0.05, length: dashDist, chamferRadius: 0)
                        let material = SCNMaterial()
                        material.diffuse.contents = color
                        material.emission.contents = color.withAlphaComponent(0.4)
                        dashGeometry.materials = [material]
                        
                        let dashNode = SCNNode(geometry: dashGeometry)
                        dashNode.position = SCNVector3(
                            (dashStart.x + dashEnd.x) / 2,
                            (dashStart.y + dashEnd.y) / 2,
                            (dashStart.z + dashEnd.z) / 2
                        )
                        
                        let angle = atan2(dashEnd.x - dashStart.x, dashEnd.z - dashStart.z)
                        dashNode.rotation = SCNVector4(0, 1, 0, Float(angle))
                        
                        parent.addChildNode(dashNode)
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
