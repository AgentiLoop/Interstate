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
        print("🛤️ Setting up dirt roads to off-road cities...")
        
        // Find cities that are FAR from any interstate
        var offRoadCities = findOffRoadCities()
        // FORCE Carson City to have dirt roads regardless
        let carsonCity = ("Carson City, NV", 39.1638, -119.7674, 25971)
        if !offRoadCities.contains(where: { $0.0 == "Carson City, NV" }) {
            offRoadCities.append(carsonCity)
            print("🚨 FORCING Carson City, NV to have dirt roads!")
        }
        
        print("🏘️ Found \(offRoadCities.count) off-road cities")
        
        // List all off-road cities found
        for city in offRoadCities {
            print("   - \(city.0)")
        }
        
        // Create dirt roads to these cities
        for (cityName, lat, lon, _) in offRoadCities {
            print("🚧 Creating dirt road to \(cityName)")
            createDirtRoadToCity(cityName: cityName, latitude: lat, longitude: lon)
        }
        
        print("✅ Dirt roads created to off-road cities")
    }
    
    private func findOffRoadCities() -> [(String, Double, Double, Int)] {
        var offRoadCities: [(String, Double, Double, Int)] = []
        let minDistanceFromInterstate: Float = 500.0 // SUPER LOW - 500m - if not RIGHT ON interstate, gets dirt road!
        
        // EVERY city needs to be checked
        for city in majorCities {
            let cityPos = gpsToSceneKit(latitude: city.1, longitude: city.2)
            var isOnInterstate = false
            
            // Check if city is DIRECTLY on an interstate route
            for (routeName, gpsCoords) in interstateRoutes {
                for (lat, lon) in gpsCoords {
                    let highwayPos = gpsToSceneKit(latitude: lat, longitude: lon)
                    let distance = sqrt(pow(cityPos.x - highwayPos.x, 2) + pow(cityPos.z - highwayPos.z, 2))
                    if Float(distance) < minDistanceFromInterstate {
                        isOnInterstate = true
                        print("✅ \(city.0) is ON \(routeName)")
                        break
                    }
                }
                if isOnInterstate { break }
            }
            
            // If NOT on interstate, it needs a dirt road!
            if !isOnInterstate {
                offRoadCities.append(city)
                print("🛤️ DIRT ROAD NEEDED: \(city.0)")
            }
        }
        
        print("📊 Total cities needing dirt roads: \(offRoadCities.count) out of \(majorCities.count)")
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
        // Create BRIGHT ORANGE-BROWN dirt road material - SUPER VISIBLE
        let dirtMaterial = SCNMaterial()
        dirtMaterial.diffuse.contents = NSColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0) // Bright orange-brown
        dirtMaterial.emission.contents = NSColor(red: 0.3, green: 0.15, blue: 0.0, alpha: 1.0) // Strong glow
        dirtMaterial.roughness.contents = 0.8
        dirtMaterial.metalness.contents = 0.0
        
        // Create segments
        for i in 0..<path.count - 1 {
            let start = path[i]
            let end = path[i + 1]
            
            // Create road segment
            let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
            
            let roadGeometry = SCNBox(width: 20.0, height: 0.2, length: CGFloat(distance), chamferRadius: 0)  // Thin dirt road
            roadGeometry.materials = [dirtMaterial]
            
            let roadNode = SCNNode(geometry: roadGeometry)
            roadNode.position = SCNVector3((start.x + end.x) / 2, 0.0, (start.z + end.z) / 2) // At ground level
            
            let angle = atan2(end.x - start.x, end.z - start.z)
            roadNode.eulerAngles = SCNVector3(0, Float(angle), 0)
            roadNode.name = "dirtRoad_\(cityName)_\(i)"
            
            scene.rootNode.addChildNode(roadNode)
            
            // Add white center line
            if distance > 2 {
                createDirtRoadCenterLine(from: start, to: end, angle: Float(angle), index: i, cityName: cityName)
            }
            
            // Add orange edge lines
            createDirtRoadEdgeLines(from: start, to: end, angle: Float(angle), index: i, cityName: cityName)
        }
    }
    
    private func createDirtRoadCenterLine(from start: SCNVector3, to end: SCNVector3, angle: Float, index: Int, cityName: String) {
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
        
        // White center line material
        let centerMaterial = SCNMaterial()
        centerMaterial.diffuse.contents = NSColor.white
        centerMaterial.emission.contents = NSColor(white: 0.2, alpha: 1.0)
        centerMaterial.roughness.contents = 0.3
        
        // Create dashed center line
        let dashLength: CGFloat = 5.0
        let gapLength: CGFloat = 5.0
        var currentDistance: CGFloat = 2.0
        
        while currentDistance + dashLength < distance - 2.0 {
            let ratio = currentDistance / CGFloat(distance)
            let dashPosition = SCNVector3(
                start.x + (end.x - start.x) * CGFloat(ratio),
                0.1,  // Slightly above dirt road surface
                start.z + (end.z - start.z) * CGFloat(ratio)
            )
            
            let centerDash = SCNBox(width: 0.3, height: 0.03, length: dashLength, chamferRadius: 0)
            centerDash.materials = [centerMaterial]
            
            let dashNode = SCNNode(geometry: centerDash)
            dashNode.position = dashPosition
            dashNode.eulerAngles = SCNVector3(0, CGFloat(angle), 0)
            dashNode.name = "dirtCenterLine_\(cityName)_\(index)"
            
            scene.rootNode.addChildNode(dashNode)
            
            currentDistance += dashLength + gapLength
        }
    }
    
    private func createDirtRoadEdgeLines(from start: SCNVector3, to end: SCNVector3, angle: Float, index: Int, cityName: String) {
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.z - start.z, 2))
        
        // Orange edge line material
        let edgeMaterial = SCNMaterial()
        edgeMaterial.diffuse.contents = NSColor.orange
        edgeMaterial.emission.contents = NSColor(red: 0.5, green: 0.25, blue: 0, alpha: 1.0)
        edgeMaterial.roughness.contents = 0.3
        
        // Calculate perpendicular offsets for edges
        let dx = Float(end.x - start.x)
        let dz = Float(end.z - start.z)
        let length = sqrt(dx * dx + dz * dz)
        let perpX = -dz / length
        let perpZ = dx / length
        
        // Create edge lines at ±10 units (20 unit wide road)
        for offset in [-10.0, 10.0] as [Float] {
            let edgeStart = SCNVector3(
                start.x + CGFloat(perpX * offset),
                0.1,  // Slightly above dirt road surface
                start.z + CGFloat(perpZ * offset)
            )
            let edgeEnd = SCNVector3(
                end.x + CGFloat(perpX * offset),
                0.1,  // Slightly above dirt road surface
                end.z + CGFloat(perpZ * offset)
            )
            
            let edgeLine = SCNBox(width: 0.3, height: 0.05, length: CGFloat(distance), chamferRadius: 0)
            edgeLine.materials = [edgeMaterial]
            
            let edgeNode = SCNNode(geometry: edgeLine)
            edgeNode.position = SCNVector3(
                (edgeStart.x + edgeEnd.x) / 2,
                0.1,  // Slightly above dirt road surface
                (edgeStart.z + edgeEnd.z) / 2
            )
            edgeNode.eulerAngles = SCNVector3(0, Float(angle), 0)
            edgeNode.name = "dirtEdgeLine_\(cityName)_\(index)"
            
            scene.rootNode.addChildNode(edgeNode)
        }
    }
} 