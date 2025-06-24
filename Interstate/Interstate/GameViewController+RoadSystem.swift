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
    
    // MARK: - Road System Setup
    
    func setupRoads() {
        // Store route data but DON'T create all roads - use dynamic loading!
        print("Setting up ultra-lightweight dynamic road loading system...")
        
        // Store ONLY GPS data for dynamic loading - don't pre-calculate anything!
        routeGPSData = interstateRoutes
        print("📍 Stored GPS data for \(routeGPSData.count) routes")
        
        // Debug: Print all unique highway names to check for duplicates
        print("🛣️ All available highways:")
        let sortedHighways = Array(interstateRoutes.keys).sorted()
        for highway in sortedHighways {
            if let coords = interstateRoutes[highway] {
                print("  - \(highway) (\(coords.count) GPS points)")
            }
        }
        
        // Check for any duplicate or weird names
        let uniqueNames = Set(sortedHighways)
        if uniqueNames.count != sortedHighways.count {
            print("⚠️ WARNING: Duplicate highway names detected!")
        }
        
        // Don't pre-calculate smooth points - calculate on demand only!
        // This saves massive amounts of memory at startup
        
        // Initialize tracking FIRST
        for routeName in routeGPSData.keys {
            loadedRoadNodes[routeName] = []
            loadedRouteSegments[routeName] = Set<Int>()
        }
        
        // Add checkpoint gates at cities AFTER route data is available
        setupCheckpointGates()
        
        // Don't find all intersection zones - calculate on demand
        // findAllIntersectionZones()
        
        print("✅ Ultra-lightweight dynamic road system ready!")
        print("📍 \(routeGPSData.count) routes prepared for on-demand loading")
        print("💾 Memory-efficient: Everything calculated on-demand only")
        
        // FORCE INITIAL ROAD LOADING - Create roads immediately at startup
        print("🚀 Force loading initial roads...")
        let playerStartPos = gpsToSceneKit(latitude: lastSavedPosition.0, longitude: lastSavedPosition.1)
        let startPosition = SCNVector3(playerStartPos.x, 0, playerStartPos.z)
        
        // Force update roads immediately
        updateDynamicRoads()
        
        print("🚀 Initial road loading completed")
    }
    
    // MARK: - Dynamic Road Loading
    
    func updateDynamicRoads() {
        autoreleasepool {
            let playerPosition = carNode.position
            
            // Only update if player moved significantly
            let distanceMoved = sqrt(pow(playerPosition.x - lastRoadUpdatePosition.x, 2) + 
                                   pow(playerPosition.z - lastRoadUpdatePosition.z, 2))
            
            if distanceMoved < CGFloat(roadUpdateThreshold) {
                return
            }
            
            lastRoadUpdatePosition = playerPosition
            
            // Check only nearby routes to save processing
            let nearbyRoutes = findNearbyRoutes(playerPosition: playerPosition)
            
            for routeName in nearbyRoutes {
                autoreleasepool {
                    // Calculate smooth points on-demand only for nearby routes
                    if routeSmoothPoints[routeName] == nil {
                        if let gpsCoordinates = routeGPSData[routeName] {
                            let smoothPoints = generateSmoothRoadPoints(from: gpsCoordinates)
                            routeSmoothPoints[routeName] = smoothPoints
                            allRoadPoints[routeName] = smoothPoints // For compatibility
                            print("📍 Generated smooth points for \(routeName) on-demand")
                        }
                    }
                    
                    if let smoothPoints = routeSmoothPoints[routeName] {
                        updateRouteSegments(routeName: routeName, smoothPoints: smoothPoints, playerPosition: playerPosition)
                    }
                }
            }
            
            // Update edge lines for loaded segments only
            updateVisibleEdgeLines()
        }
    }
    
    func updateRouteSegments(routeName: String, smoothPoints: [(Float, Float)], playerPosition: SCNVector3) {
        autoreleasepool {
            guard var loadedSegments = loadedRouteSegments[routeName] else { return }
            var nodesToAdd: [SCNNode] = []
            var segmentsToLoad: Set<Int> = Set()
            var segmentsToUnload: Set<Int> = Set()
            
            // Check which segments should be loaded
            for i in 0..<smoothPoints.count - 1 {
                let start = smoothPoints[i]
                let end = smoothPoints[i + 1]
                let segmentCenter = SCNVector3((start.0 + end.0) / 2, 0, (start.1 + end.1) / 2)
                
                let distanceToPlayer = sqrt(pow(playerPosition.x - segmentCenter.x, 2) + 
                                          pow(playerPosition.z - segmentCenter.z, 2))
                
                let isLoaded = loadedSegments.contains(i)
                
                if Float(distanceToPlayer) <= roadLoadDistance && !isLoaded {
                    // Load this segment
                    segmentsToLoad.insert(i)
                }
                // REMOVED: Don't unload segments - keep roads visible
            }
            
            // Load new segments
            for segmentIndex in segmentsToLoad {
                autoreleasepool {
                    if segmentIndex < smoothPoints.count - 1 {
                        let start = smoothPoints[segmentIndex]
                        let end = smoothPoints[segmentIndex + 1]
                        
                        // Check if this segment already exists to prevent duplicates
                        let segmentName = "\(routeName)_\(segmentIndex)_container"
                        if scene.rootNode.childNode(withName: segmentName, recursively: true) == nil {
                            let roadNode = createRoadSegmentNode(
                                from: SCNVector3(start.0, 0, start.1),
                                to: SCNVector3(end.0, 0, end.1),
                                routeName: routeName,
                                segmentIndex: segmentIndex
                            )
                            
                            scene.rootNode.addChildNode(roadNode)
                            loadedRoadNodes[routeName]?.append(roadNode)
                            loadedSegments.insert(segmentIndex)
                        } else {
                            print("⚠️ Skipping duplicate segment: \(segmentName)")
                            loadedSegments.insert(segmentIndex) // Still mark as loaded
                        }
                    }
                }
            }
            
            loadedRouteSegments[routeName] = loadedSegments
            
            // Debug info (remove in production)
            if !segmentsToLoad.isEmpty || !segmentsToUnload.isEmpty {
                print("🛣️ \(routeName): +\(segmentsToLoad.count) -\(segmentsToUnload.count) segments (total: \(loadedSegments.count))")
            }
        }
    }
    
    func createRoadSegmentNode(from start: SCNVector3, to end: SCNVector3, routeName: String, segmentIndex: Int) -> SCNNode {
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
        
        // Container for this segment
        let segmentContainer = SCNNode()
        segmentContainer.name = "\(routeName)_\(segmentIndex)_container"
        
        // Create curved road surface using bezier paths for smoother curves
        let roadNode = createBezierRoadSegment(from: start, to: end, segmentIndex: segmentIndex)
        roadNode.name = "\(routeName)_\(segmentIndex)_road"
        segmentContainer.addChildNode(roadNode)
        
        // Add center markings if segment is long enough
        if distance > 2 { // Adjusted for higher segment density
            let centerLineNodes = createSmoothCenterLineNodes(from: start, to: end, routeName: routeName, segmentIndex: segmentIndex)
            for centerNode in centerLineNodes {
                segmentContainer.addChildNode(centerNode)
            }
        }
        
        // Add continuous edge lines
        let edgeNodes = createSegmentEdgeLines(from: start, to: end, routeName: routeName, segmentIndex: segmentIndex)
        for edgeNode in edgeNodes {
            segmentContainer.addChildNode(edgeNode)
        }
        
        return segmentContainer
    }
    
    func createBezierRoadSegment(from start: SCNVector3, to end: SCNVector3, segmentIndex: Int) -> SCNNode {
        // For very short segments, just use a simple box
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
        
        // Add 30 pixels (approximately 1.0 units) overlap to each segment
        let overlapAmount: CGFloat = 1.0  // 30 pixels overlap
        let extendedLength = CGFloat(distance) + overlapAmount
        
        // Since we now have 50 segments per section, each segment is very short
        // This means we can use simple geometry and still achieve smooth curves
        let roadGeometry = SCNBox(width: 20.0, height: 0.5, length: extendedLength, chamferRadius: 0.05)
        
        // Minimal subdivision for performance
        roadGeometry.widthSegmentCount = 1
        roadGeometry.lengthSegmentCount = 1
        roadGeometry.heightSegmentCount = 1
        
        // Enhanced road material
        let roadMaterial = SCNMaterial()
        roadMaterial.diffuse.contents = NSColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1.0)
        roadMaterial.roughness.contents = 0.8
        roadMaterial.metalness.contents = 0.1
        
        roadGeometry.materials = [roadMaterial]
        
        let roadNode = SCNNode(geometry: roadGeometry)
        
        // Extend the segment position slightly beyond the endpoints for overlap
        let dx = Float(end.x - start.x)
        let dz = Float(end.z - start.z)
        let normalizedDx = dx / Float(distance)
        let normalizedDz = dz / Float(distance)
        let extendDistance = Float(overlapAmount) / 2.0
        
        // Adjust position to account for extended length
        roadNode.position = SCNVector3((start.x + end.x) / 2, 0, (start.z + end.z) / 2)
        
        let angle = atan2(end.x - start.x, end.z - start.z)
        roadNode.eulerAngles = SCNVector3(0, Float(angle), 0)
        
        return roadNode
    }
    
    func createSmoothCenterLineNodes(from start: SCNVector3, to end: SCNVector3, routeName: String, segmentIndex: Int) -> [SCNNode] {
        var centerNodes: [SCNNode] = []
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
        
        // With 50 segments per section, each segment is very short
        // Only add dashes to longer segments to avoid overcrowding
        if distance < 2.0 {
            return []  // Skip very short segments
        }
        
        let dashLength: CGFloat = 4.0  // Even shorter dashes for high-density segments
        let gapLength: CGFloat = 3.0   // Shorter gaps
        
        var currentDistance: CGFloat = 1.0
        var dashIndex = 0
        
        // Calculate road direction for proper dash alignment
        let roadAngle = atan2(end.x - start.x, end.z - start.z)
        
        while currentDistance + dashLength < distance - 2.0 {
            let ratio = currentDistance / CGFloat(distance)
            let dashPosition = SCNVector3(
                start.x + (end.x - start.x) * CGFloat(ratio),
                0.35,
                start.z + (end.z - start.z) * CGFloat(ratio)
            )
            
            // Check if not in intersection zone
            var inIntersection = false
            for zone in intersectionZones {
                let distToZone = sqrt(pow(dashPosition.x - zone.x, 2) + pow(dashPosition.z - zone.z, 2))
                if distToZone < CGFloat(intersectionRadius) {
                    inIntersection = true
                    break
                }
            }
            
            if !inIntersection {
                // Enhanced center dash with better materials
                let centerDash = SCNBox(width: 0.4, height: 0.12, length: CGFloat(dashLength), chamferRadius: 0.05)
                
                let dashMaterial = SCNMaterial()
                dashMaterial.diffuse.contents = NSColor.yellow
                dashMaterial.emission.contents = NSColor(red: 0.4, green: 0.4, blue: 0, alpha: 1)
                dashMaterial.roughness.contents = 0.3
                
                centerDash.materials = [dashMaterial]
                
                let dashNode = SCNNode(geometry: centerDash)
                dashNode.position = dashPosition
                dashNode.eulerAngles = SCNVector3(0, Float(roadAngle), 0)
                dashNode.name = "\(routeName)_\(segmentIndex)_dash_\(dashIndex)"
                centerNodes.append(dashNode)
                dashIndex += 1
            }
            
            currentDistance += dashLength + gapLength
        }
        
        return centerNodes
    }
    
    func createSegmentEdgeLines(from start: SCNVector3, to end: SCNVector3, routeName: String, segmentIndex: Int) -> [SCNNode] {
        var edgeNodes: [SCNNode] = []
        let edgeOffsets: [Float] = [-10.0, 10.0]  // Road edges at ±10 units
        
        let dx = Float(end.x - start.x)
        let dz = Float(end.z - start.z)
        let length = sqrt(dx * dx + dz * dz)
        
        guard length > 0 else { return [] }
        
        let perpX = -dz / length
        let perpZ = dx / length
        
        for (edgeIndex, offset) in edgeOffsets.enumerated() {
            let edgeStart = SCNVector3(
                start.x + CGFloat(perpX * offset),
                0.35,
                start.z + CGFloat(perpZ * offset)
            )
            let edgeEnd = SCNVector3(
                end.x + CGFloat(perpX * offset),
                0.35,
                end.z + CGFloat(perpZ * offset)
            )
            
            let edgeDistance = sqrt(pow(edgeEnd.x - edgeStart.x, 2) + pow(edgeEnd.z - edgeStart.z, 2))
            
            // Create continuous white edge line
            let edgeLine = SCNBox(width: 0.5, height: 0.15, length: CGFloat(edgeDistance), chamferRadius: 0.05)
            
            let edgeMaterial = SCNMaterial()
            edgeMaterial.diffuse.contents = NSColor.white
            edgeMaterial.emission.contents = NSColor(white: 0.15, alpha: 1.0)
            edgeMaterial.roughness.contents = 0.2
            
            edgeLine.materials = [edgeMaterial]
            
            let edgeNode = SCNNode(geometry: edgeLine)
            edgeNode.position = SCNVector3(
                (edgeStart.x + edgeEnd.x) / 2,
                0.35,
                (edgeStart.z + edgeEnd.z) / 2
            )
            edgeNode.name = "\(routeName)_\(segmentIndex)_edgeLine_\(edgeIndex)"
            
            let angle = atan2(edgeEnd.x - edgeStart.x, edgeEnd.z - edgeStart.z)
            edgeNode.eulerAngles = SCNVector3(0, Float(angle), 0)
            
            edgeNodes.append(edgeNode)
        }
        
        return edgeNodes
    }
    
    func updateVisibleEdgeLines() {
        autoreleasepool {
            // Create edge lines only for loaded segments
            for (routeName, segments) in loadedRouteSegments {
                autoreleasepool {
                    guard let smoothPoints = routeSmoothPoints[routeName] else { return }
                    
                    for segmentIndex in segments {
                        if segmentIndex < smoothPoints.count - 1 {
                            let start = smoothPoints[segmentIndex]
                            let end = smoothPoints[segmentIndex + 1]
                            createEdgeLinesForSegment(
                                from: (start.0, start.1),
                                to: (end.0, end.1),
                                routeName: routeName,
                                segmentIndex: segmentIndex
                            )
                        }
                    }
                }
            }
        }
    }
    
    func createEdgeLinesForSegment(from start: (Float, Float), to end: (Float, Float), routeName: String, segmentIndex: Int) {
        let edgeOffsets: [Float] = [-10.0, 10.0]  // Road edges
        
        for (edgeIndex, offset) in edgeOffsets.enumerated() {
            let dx = end.0 - start.0
            let dz = end.1 - start.1
            let length = sqrt(dx * dx + dz * dz)
            
            if length > 0 {
                let perpX = -dz / length * offset
                let perpZ = dx / length * offset
                
                let edgeStart = SCNVector3(start.0 + perpX, 0.35, start.1 + perpZ)
                let edgeEnd = SCNVector3(end.0 + perpX, 0.35, end.1 + perpZ)
                let distance = sqrt(pow(edgeEnd.x - edgeStart.x, 2) + pow(edgeEnd.z - edgeStart.z, 2))
                
                // Enhanced edge line with better materials
                let edgeLine = SCNBox(width: 0.4, height: 0.12, length: CGFloat(distance), chamferRadius: 0.05)
                
                let edgeMaterial = SCNMaterial()
                edgeMaterial.diffuse.contents = NSColor.white
                edgeMaterial.emission.contents = NSColor(white: 0.1, alpha: 1.0)
                edgeMaterial.roughness.contents = 0.2
                
                edgeLine.materials = [edgeMaterial]
                
                let edgeNode = SCNNode(geometry: edgeLine)
                edgeNode.position = SCNVector3((edgeStart.x + edgeEnd.x) / 2, 0.35, (edgeStart.z + edgeEnd.z) / 2)
                edgeNode.name = "\(routeName)_\(segmentIndex)_edgeLine_\(edgeIndex)"
                
                let angle = atan2(edgeEnd.x - edgeStart.x, edgeEnd.z - edgeStart.z)
                edgeNode.eulerAngles = SCNVector3(0, Float(angle), 0)
                scene.rootNode.addChildNode(edgeNode)
            }
        }
    }
    
    func findNearbyRoutes(playerPosition: SCNVector3) -> [String] {
        var nearbyRoutes: [String] = []
        let maxRouteCheckDistance: Float = 10000.0 // Increased to 10km to ensure we find routes
        
        print("🔍 Finding nearby routes from position: \(playerPosition)")
        print("🔍 Checking \(routeGPSData.count) total routes")
        
        for (routeName, gpsCoordinates) in routeGPSData {
            // Quick check: is any point in this route near the player?
            var isNearby = false
            var minDistance: Float = Float.infinity
            
            // Check every GPS point for debugging (was every 5th)
            for i in 0..<gpsCoordinates.count {
                let (lat, lon) = gpsCoordinates[i]
                let routePoint = gpsToSceneKit(latitude: lat, longitude: lon)
                let distance = sqrt(pow(playerPosition.x - routePoint.x, 2) + 
                                  pow(playerPosition.z - routePoint.z, 2))
                
                if Float(distance) < minDistance {
                    minDistance = Float(distance)
                }
                
                if Float(distance) <= maxRouteCheckDistance {
                    isNearby = true
                    break
                }
            }
            
            if isNearby {
                nearbyRoutes.append(routeName)
                print("✅ Found nearby route: \(routeName) (closest point: \(Int(minDistance))m)")
            } else {
                print("❌ Route \(routeName) too far (closest: \(Int(minDistance))m)")
            }
        }
        
        print("🔍 Found \(nearbyRoutes.count) nearby routes: \(nearbyRoutes)")
        return nearbyRoutes
    }
    
    // MARK: - Intersection Finding
    
    func findAllIntersectionZones() {
        // Find all points where interstates cross
        let routeNames = Array(allRoadPoints.keys)
        
        for i in 0..<routeNames.count {
            for j in i+1..<routeNames.count {
                let route1Points = allRoadPoints[routeNames[i]] ?? []
                let route2Points = allRoadPoints[routeNames[j]] ?? []
                
                // Check for intersections between all segments
                for k in 0..<route1Points.count-1 {
                    for l in 0..<route2Points.count-1 {
                        let p1 = route1Points[k]
                        let p2 = route1Points[k+1]
                        let p3 = route2Points[l]
                        let p4 = route2Points[l+1]
                        
                        if let intersection = lineIntersection(p1: p1, p2: p2, p3: p3, p4: p4) {
                            let intersectionPoint = SCNVector3(CGFloat(intersection.0), CGFloat(0), CGFloat(intersection.1))
                            
                            // Check if we already have an intersection zone near this point
                            var alreadyExists = false
                            for zone in intersectionZones {
                                let dist = sqrt(pow(zone.x - intersectionPoint.x, 2) + pow(zone.z - intersectionPoint.z, 2))
                                if dist < CGFloat(intersectionRadius * 0.5) {
                                    alreadyExists = true
                                    break
                                }
                            }
                            
                            if !alreadyExists {
                                intersectionZones.append(intersectionPoint)
                            }
                        }
                    }
                }
            }
        }
    }
}