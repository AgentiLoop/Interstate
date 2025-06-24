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
        print("🚀 Setting up memory-managed road system...")
        
        // Setup memory-managed route loading instead of loading all routes
        setupMemoryManagedRouteSystem()
        
        // Debug: Print all available highways from the master list
        print("🛣️ Master highway list:")
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
        
        // Add checkpoint gates at cities
        setupCheckpointGates()
        
        print("✅ Memory-managed road system ready!")
        
        // Force initial road loading
        print("🚀 Force loading initial roads...")
        
        // FORCED UPDATE: Bypass all thresholds for initial loading
        lastRoadUpdatePosition = SCNVector3(-99999, -99999, -99999) // Force update
        updateDynamicRoads()
        
        // Also try to manually trigger road generation for any loaded routes
        print("🔍 Attempting to generate roads for loaded routes...")
        let currentlyLoaded = Array(loadedRouteData)
        print("📋 Currently loaded routes: \(currentlyLoaded.joined(separator: ", "))")
        
        if !currentlyLoaded.isEmpty {
            for routeName in currentlyLoaded {
                if let gpsCoordinates = getRouteData(routeName: routeName) {
                    let smoothPoints = generateSmoothRoadPoints(from: gpsCoordinates)
                    routeSmoothPoints[routeName] = smoothPoints
                    allRoadPoints[routeName] = smoothPoints
                    print("🛣️ Pre-generated smooth points for \(routeName) (\(smoothPoints.count) points)")
                }
            }
            
            // Force another road update now that we have smooth points
            updateDynamicRoads()
        } else {
            print("⚠️ No routes loaded yet during initial setup")
        }
        
        print("🚀 Initial road loading completed")
    }
    
    // MARK: - Dynamic Road Loading
    
    func updateDynamicRoads() {
        // URGENT DEBUG: This should appear every frame
        NSLog("🚨 DEBUG: updateDynamicRoads ENTRY")
        print("🚨 URGENT DEBUG: updateDynamicRoads function called!")
        
        autoreleasepool {
            let playerPosition = carNode.position
            NSLog("🚨 DEBUG: Got player position: %f, %f", playerPosition.x, playerPosition.z)
            
            print("🔄 updateDynamicRoads called at position (\(Int(playerPosition.x)), \(Int(playerPosition.z)))")
            
            // Memory management happens automatically in background thread
            
            // Only update if player moved significantly
            let distanceMoved = sqrt(pow(playerPosition.x - lastRoadUpdatePosition.x, 2) + 
                                   pow(playerPosition.z - lastRoadUpdatePosition.z, 2))
            
            if distanceMoved < CGFloat(roadUpdateThreshold) {
                print("📍 Player hasn't moved enough (\(Int(distanceMoved))m < \(roadUpdateThreshold)m), skipping road update")
                return
            }
            
            lastRoadUpdatePosition = playerPosition
            
            // Check only loaded routes to save processing
            let nearbyRoutes = findLoadedNearbyRoutes(playerPosition: playerPosition)
            
            if nearbyRoutes.isEmpty {
                print("❌ No nearby routes found to render!")
                return
            }
            
            for routeName in nearbyRoutes {
                autoreleasepool {
                    // Calculate smooth points on-demand only for loaded routes
                    if routeSmoothPoints[routeName] == nil {
                        if let gpsCoordinates = getRouteData(routeName: routeName) {
                            let smoothPoints = generateSmoothRoadPoints(from: gpsCoordinates)
                            routeSmoothPoints[routeName] = smoothPoints
                            allRoadPoints[routeName] = smoothPoints // For compatibility
                            print("📍 Generated smooth points for \(routeName) on-demand (\(smoothPoints.count) points)")
                            
                            // Memory tracking handled by the new system automatically
                        } else {
                            print("❌ Could not get GPS coordinates for \(routeName)")
                        }
                    }
                    
                    if let smoothPoints = routeSmoothPoints[routeName] {
                        print("🛣️ Processing road segments for \(routeName) (\(smoothPoints.count) smooth points)")
                        updateRouteSegments(routeName: routeName, smoothPoints: smoothPoints, playerPosition: playerPosition)
                    } else {
                        print("❌ No smooth points available for \(routeName)")
                    }
                }
            }
            
            // Update edge lines for loaded segments only
            updateVisibleEdgeLines()
            
            print("✅ Road update completed for \(nearbyRoutes.count) routes")
        }
    }
    
    func loadRoadSegmentsInBackground(routeName: String, smoothPoints: [(Float, Float)], segmentsToLoad: Set<Int>) {
        print("🚧 Loading \(segmentsToLoad.count) road segments for \(routeName) in background")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var roadNodesToAdd: [SCNNode] = []
            
            autoreleasepool {
                for segmentIndex in segmentsToLoad {
                    if segmentIndex < smoothPoints.count - 1 {
                        let start = smoothPoints[segmentIndex]
                        let end = smoothPoints[segmentIndex + 1]
                        
                        // Create road node in background
                        let roadNode = self.createRoadSegmentNode(
                            from: SCNVector3(start.0, 0, start.1),
                            to: SCNVector3(end.0, 0, end.1),
                            routeName: routeName,
                            segmentIndex: segmentIndex
                        )
                        
                        roadNodesToAdd.append(roadNode)
                    }
                }
            }
            
            print("🎨 Created \(roadNodesToAdd.count) road nodes for \(routeName), adding to scene...")
            
            // Add nodes to scene on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var addedCount = 0
                for roadNode in roadNodesToAdd {
                    // Check if segment still doesn't exist
                    if let nodeName = roadNode.name,
                       self.scene.rootNode.childNode(withName: nodeName, recursively: true) == nil {
                        
                        self.scene.rootNode.addChildNode(roadNode)
                        
                        // Initialize arrays if needed
                        if self.loadedRoadNodes[routeName] == nil {
                            self.loadedRoadNodes[routeName] = []
                        }
                        self.loadedRoadNodes[routeName]?.append(roadNode)
                        
                        // Extract segment index from node name
                        let components = nodeName.components(separatedBy: "_")
                        if components.count >= 2, let segmentIndex = Int(components[1]) {
                            if self.loadedRouteSegments[routeName] == nil {
                                self.loadedRouteSegments[routeName] = Set<Int>()
                            }
                            self.loadedRouteSegments[routeName]?.insert(segmentIndex)
                        }
                        
                        addedCount += 1
                    }
                }
                
                print("✅ Added \(addedCount) road segments to scene for \(routeName)")
                print("🎯 Total scene children: \(self.scene.rootNode.childNodes.count)")
            }
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
            
                         // Load new segments in background to prevent game pauses
             if !segmentsToLoad.isEmpty {
                 loadRoadSegmentsInBackground(routeName: routeName, smoothPoints: smoothPoints, segmentsToLoad: segmentsToLoad)
             }
            
            loadedRouteSegments[routeName] = loadedSegments
            
            // Silent road loading - removed debug spam
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
    
    func findLoadedNearbyRoutes(playerPosition: SCNVector3) -> [String] {
        var nearbyRoutes: [String] = []
        let maxRouteCheckDistance: Float = 5000.0 // 5km range for road rendering
        
        // Debug: Print what routes are loaded
        let loadedRoutes = Array(loadedRouteData)
        if !loadedRoutes.isEmpty {
            print("🔍 Checking \(loadedRoutes.count) loaded routes: \(loadedRoutes.joined(separator: ", "))")
        }
        
        // Only check routes that are currently loaded in memory
        for routeName in loadedRouteData {
            guard let gpsCoordinates = getRouteData(routeName: routeName) else {
                print("❌ Could not get route data for \(routeName)")
                continue
            }
            
            // Quick check: is any point in this route near the player?
            var minDistance: Float = Float.infinity
            
            // Check every GPS point to be more thorough
            for (lat, lon) in gpsCoordinates {
                let routePoint = gpsToSceneKit(latitude: lat, longitude: lon)
                let distance = sqrt(pow(playerPosition.x - routePoint.x, 2) + 
                                  pow(playerPosition.z - routePoint.z, 2))
                
                if Float(distance) < minDistance {
                    minDistance = Float(distance)
                }
            }
            
            print("🛣️ Route \(routeName): closest point \(Int(minDistance))m from player")
            
            if minDistance <= maxRouteCheckDistance {
                nearbyRoutes.append(routeName)
                print("✅ \(routeName) added to nearby routes")
            } else {
                print("❌ \(routeName) too far (\(Int(minDistance))m > \(Int(maxRouteCheckDistance))m)")
            }
        }
        
        print("🎯 Found \(nearbyRoutes.count) nearby routes: \(nearbyRoutes.joined(separator: ", "))")
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