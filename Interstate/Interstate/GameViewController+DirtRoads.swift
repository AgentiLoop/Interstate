//
//  GameViewController+DirtRoads.swift
//  Interstate
//
//  Dirt roads to off-road cities - SEPARATE from interstate system
//

import SceneKit
import Foundation

extension GameViewController {
    
    // MARK: - Dirt Road System
    
    func setupDirtRoads() {
        // Find cities that are FAR from any interstate
        var offRoadCities = findOffRoadCities()
        // FORCE Carson City to have dirt roads regardless
        let carsonCity = ("Carson City, NV", 39.1638, -119.7674, 25971)
        if !offRoadCities.contains(where: { $0.0 == "Carson City, NV" }) {
            offRoadCities.append(carsonCity)
        }
        
        // Create dirt roads to these cities
        for (cityName, lat, lon, _) in offRoadCities {
            createDirtRoadToCity(cityName: cityName, latitude: lat, longitude: lon)
        }
    }
    
    private func findOffRoadCities() -> [(String, Double, Double, Int)] {
        var offRoadCities: [(String, Double, Double, Int)] = []
        let minDistanceFromInterstate: Float = 500.0 // SUPER LOW - 500m - if not RIGHT ON interstate, gets dirt road!
        
        // EVERY city needs to be checked
        for city in majorCities {
            let cityPos = gpsToSceneKit(latitude: city.1, longitude: city.2)
            var isOnInterstate = false
            
            // Check if city is DIRECTLY on an interstate route
            for (_, gpsCoords) in interstateRoutes {
                for (lat, lon) in gpsCoords {
                    let highwayPos = gpsToSceneKit(latitude: lat, longitude: lon)
                    let distance = sqrt(pow(cityPos.x - highwayPos.x, 2) + pow(cityPos.z - highwayPos.z, 2))
                    if Float(distance) < minDistanceFromInterstate {
                        isOnInterstate = true
                        break
                    }
                }
                if isOnInterstate { break }
            }
            
            // If NOT on interstate, it needs a dirt road!
            if !isOnInterstate {
                offRoadCities.append(city)
            }
        }
        
        return offRoadCities
    }
    
    private func createDirtRoadToCity(cityName: String, latitude: Double, longitude: Double) {
        let cityPos = gpsToSceneKit(latitude: latitude, longitude: longitude)
        
        // Create multiple dirt roads extending in different directions from the city
        let directions = [
            (1.0, 0.0),    // East
            (-1.0, 0.0),   // West
            (0.0, 1.0),    // North
            (0.0, -1.0),   // South
            (0.7, 0.7),    // Northeast
            (-0.7, 0.7),   // Northwest
            (0.7, -0.7),   // Southeast
            (-0.7, -0.7)   // Southwest
        ]
        
        // Create 2-4 random dirt roads from this city
        let numRoads = Int.random(in: 2...4)
        let selectedDirections = directions.shuffled().prefix(numRoads)
        
        for (index, (dx, dz)) in selectedDirections.enumerated() {
            // Create endpoint 5-10km away in that direction
            let distance = Float.random(in: 5000...10000)
            let endpoint = SCNVector3(
                cityPos.x + CGFloat(dx * Double(distance)),
                0,
                cityPos.z + CGFloat(dz * Double(distance))
            )
            
            // Generate twisty path from city to endpoint
            let twistyPath = generateTwistyDirtPath(from: cityPos, to: endpoint)
            
            // Create the dirt road segments
            createDirtRoadSegments(path: twistyPath, cityName: "\(cityName)_road\(index)")
        }
    }
    
    private func findDirtRoadConnectionPoint(cityPos: SCNVector3) -> SCNVector3 {
        // Find a point that's halfway between the city and the nearest interstate area
        var nearestPoint = cityPos
        var minDistance: Float = Float.infinity
        
        // Sample some interstate points to find general direction
        for (_, gpsCoords) in interstateRoutes {
            // Just check a few points per route for performance
            let sampleIndices = [0, gpsCoords.count/4, gpsCoords.count/2, 3*gpsCoords.count/4, gpsCoords.count-1]
            
            for index in sampleIndices {
                if index < gpsCoords.count {
                    let (lat, lon) = gpsCoords[index]
                    let highwayPos = gpsToSceneKit(latitude: lat, longitude: lon)
                    let distance = sqrt(pow(cityPos.x - highwayPos.x, 2) + pow(cityPos.z - highwayPos.z, 2))
                    
                    if Float(distance) < minDistance {
                        minDistance = Float(distance)
                        // Connection point is 1/3 of the way from city to highway
                        nearestPoint = SCNVector3(
                            cityPos.x + (highwayPos.x - cityPos.x) * 0.33,
                            0,
                            cityPos.z + (highwayPos.z - cityPos.z) * 0.33
                        )
                    }
                }
            }
        }
        
        return nearestPoint
    }
    
    private func generateTwistyDirtPath(from start: SCNVector3, to end: SCNVector3) -> [SCNVector3] {
        // USE THE SAME SMOOTH GENERATION AS REGULAR ROADS!
        var controlPoints: [SCNVector3] = []
        
        // Add start point
        controlPoints.append(start)
        
        // Calculate base direction
        let dx = end.x - start.x
        let dz = end.z - start.z
        let distance = sqrt(dx * dx + dz * dz)
        
        // Generate intermediate control points with natural curves
        let numControlPoints = max(3, Int(distance / 2000) + 2) // Fewer control points for smoother curves
        
        for i in 1..<numControlPoints {
            let t = CGFloat(i) / CGFloat(numControlPoints)
            
            // Base position along straight line
            let baseX = start.x + dx * t
            let baseZ = start.z + dz * t
            
            // Add perpendicular offset for gentle curves
            let perpX = -dz / distance
            let perpZ = dx / distance
            
            // Create gentle curves with some variation
            let curveAmplitude = CGFloat.random(in: 200...400) // Gentle curves
            let curveOffset = sin(t * CGFloat.pi * 2 + CGFloat.random(in: 0...CGFloat.pi)) * curveAmplitude
            
            let curveX = baseX + perpX * curveOffset
            let curveZ = baseZ + perpZ * curveOffset
            
            controlPoints.append(SCNVector3(curveX, 0, curveZ))
        }
        
        // Add end point
        controlPoints.append(end)
        
        // Now use the SAME smooth road generation as highways
        var smoothPath: [(Float, Float)] = []
        let segmentsPerSection = 50 // Same high-quality smoothing as highways
        
        for i in 0..<controlPoints.count - 1 {
            // Get control points (handle edge cases)
            let p0 = i > 0 ? controlPoints[i-1] : controlPoints[i]
            let p1 = controlPoints[i]
            let p2 = controlPoints[i+1]
            let p3 = i < controlPoints.count - 2 ? controlPoints[i+2] : controlPoints[i+1]
            
            // Generate smooth points using Catmull-Rom spline - SAME AS HIGHWAYS
            for j in 0..<segmentsPerSection {
                let t = Float(j) / Float(segmentsPerSection)
                let smoothPoint = catmullRomSpline(p0, p1, p2, p3, t)
                smoothPath.append((Float(smoothPoint.x), Float(smoothPoint.z)))
            }
        }
        
        // Add final point
        if let lastPoint = controlPoints.last {
            smoothPath.append((Float(lastPoint.x), Float(lastPoint.z)))
        }
        
        // Convert back to SCNVector3 array
        return smoothPath.map { SCNVector3(CGFloat($0.0), 0, CGFloat($0.1)) }
    }
    
    private func createDirtRoadSegments(path: [SCNVector3], cityName: String) {
        // Convert path to 2D points format
        var points: [(CGFloat, CGFloat)] = []
        for point in path {
            // Lower dirt roads by 0.05 units so paved roads go over them
            points.append((point.x, point.z))
        }
        
        // Create the dirt road with custom marking colors
        let roadNode = createDirtRoadSegmentNode(points: points, routeName: "dirt_\(cityName)")
        
        // Lower the entire road node so paved roads appear on top
        roadNode.position.y = -0.05
        
        roadNode.name = "dirtRoad_\(cityName)"
        
        // Mark this as a dirt road for identification and z-ordering
        roadNode.enumerateChildNodes { (node, _) in
            if let name = node.name {
                node.name = "dirt_\(name)"
            } else {
                node.name = "dirt_segment"
            }
        }
        
        scene.rootNode.addChildNode(roadNode)
    }
    
    // Custom dirt road creation with orange center lines and brown edge lines
    private func createDirtRoadSegmentNode(points: [(CGFloat, CGFloat)], routeName: String) -> SCNNode {
        let roadNode = SCNNode()
        
        // Create curved road segments with dirt material
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
        
        // Add dirt road markings with custom colors
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
        let roadGeometry = SCNBox(width: 20.0, height: 0.1, length: CGFloat(distance) + 0.5, chamferRadius: 0)
        
        // Dirt road surface material
        let dirtMaterial = SCNMaterial()
        dirtMaterial.diffuse.contents = NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0) // Dirt brown
        dirtMaterial.emission.contents = NSColor(red: 0.1, green: 0.05, blue: 0.0, alpha: 1.0)
        dirtMaterial.roughness.contents = 0.9
        dirtMaterial.metalness.contents = 0.0
        roadGeometry.materials = [dirtMaterial]
        
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
    
    private func createDirtRoadMarkings(roadNode: SCNNode, points: [(CGFloat, CGFloat)], routeName: String) {
        guard points.count >= 10 else { return }
        
        // DIRT ROAD MARKINGS:
        // 1. DARK BROWN LINES on edges
        // 2. ORANGE DASHED LINE in center
        
        createDirtRoadEdgeLines(roadNode: roadNode, points: points)
        createDirtRoadCenterDashes(roadNode: roadNode, points: points)
    }
    
    private func createDirtRoadEdgeLines(roadNode: SCNNode, points: [(CGFloat, CGFloat)]) {
        // Create CONTINUOUS CURVED dark brown edge lines
        let edgeOffsets: [CGFloat] = [-10.0, 10.0] // Left and right edges
        let darkBrown = NSColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0) // Dark brown color
        
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
            createContinuousCurvedLine(points: edgePoints, color: darkBrown, width: 0.5, parent: roadNode)
        }
    }
    
    private func createDirtRoadCenterDashes(roadNode: SCNNode, points: [(CGFloat, CGFloat)]) {
        // Create ORANGE DASHES along the center curve
        var centerPoints: [SCNVector3] = []
        let orange = NSColor.orange // Bright orange for dirt road center
        
        // Convert road points to center line (no offset needed for center)
        for point in points {
            centerPoints.append(SCNVector3(point.0, 0.15, point.1))
        }
        
        // Create dashed orange center line
        createDashedCurvedLine(points: centerPoints, color: orange, width: 0.5, 
                              dashLength: 10.0, gapLength: 15.0, parent: roadNode)
    }
    
    // Helper functions for creating curved lines
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