//
//  GameViewController+HighwayConnections.swift
//  Interstate
//
//  Connects nearby interstate highways with dirt roads
//

import SceneKit
import Foundation

extension GameViewController {
    
    // MARK: - Highway Connection System
    
    func setupHighwayConnections() {
        print("🛣️ Setting up highway connections...")
        
        var connectionsCreated = 0
        var directConnections = 0
        var pavedConnections = 0
        var dirtConnections = 0
        
        // Process all precomputed connections
        for (fromRoute, connections) in highwayConnections {
            guard let fromCoords = interstateRoutes[fromRoute] else { continue }
            
            for (toRoute, distance, type) in connections {
                guard let toCoords = interstateRoutes[toRoute] else { continue }
                
                // Skip direct connections (distance 0) - they already share points
                if distance == 0 {
                    directConnections += 1
                    continue
                }
                
                // Find the closest points between the two routes
                var minDist = CGFloat.infinity
                var bestFromPoint: SCNVector3?
                var bestToPoint: SCNVector3?
                
                // Check endpoints first
                let fromEndpoints = [
                    gpsToSceneKit(latitude: fromCoords.first!.0, longitude: fromCoords.first!.1),
                    gpsToSceneKit(latitude: fromCoords.last!.0, longitude: fromCoords.last!.1)
                ]
                let toEndpoints = [
                    gpsToSceneKit(latitude: toCoords.first!.0, longitude: toCoords.first!.1),
                    gpsToSceneKit(latitude: toCoords.last!.0, longitude: toCoords.last!.1)
                ]
                
                // Find closest endpoints
                for fromPoint in fromEndpoints {
                    for toPoint in toEndpoints {
                        let dist = sqrt(pow(fromPoint.x - toPoint.x, 2) + pow(fromPoint.z - toPoint.z, 2))
                        if dist < minDist {
                            minDist = dist
                            bestFromPoint = fromPoint
                            bestToPoint = toPoint
                        }
                    }
                }
                
                // Also check some midpoints if routes are long enough
                if fromCoords.count >= 10 && toCoords.count >= 10 {
                    let fromMidpoints = [
                        gpsToSceneKit(latitude: fromCoords[fromCoords.count/4].0, longitude: fromCoords[fromCoords.count/4].1),
                        gpsToSceneKit(latitude: fromCoords[fromCoords.count/2].0, longitude: fromCoords[fromCoords.count/2].1),
                        gpsToSceneKit(latitude: fromCoords[3*fromCoords.count/4].0, longitude: fromCoords[3*fromCoords.count/4].1)
                    ]
                    let toMidpoints = [
                        gpsToSceneKit(latitude: toCoords[toCoords.count/4].0, longitude: toCoords[toCoords.count/4].1),
                        gpsToSceneKit(latitude: toCoords[toCoords.count/2].0, longitude: toCoords[toCoords.count/2].1),
                        gpsToSceneKit(latitude: toCoords[3*toCoords.count/4].0, longitude: toCoords[3*toCoords.count/4].1)
                    ]
                    
                    for fromPoint in fromMidpoints {
                        for toPoint in toMidpoints {
                            let dist = sqrt(pow(fromPoint.x - toPoint.x, 2) + pow(fromPoint.z - toPoint.z, 2))
                            if dist < minDist {
                                minDist = dist
                                bestFromPoint = fromPoint
                                bestToPoint = toPoint
                            }
                        }
                    }
                }
                
                // Create the connection if we found good points
                if let fromPoint = bestFromPoint, let toPoint = bestToPoint {
                    let connectionName = "\(fromRoute)_to_\(toRoute)_connector"
                    
                    if type == "paved" {
                        createPavedConnector(from: fromPoint, to: toPoint, name: connectionName)
                        pavedConnections += 1
                    } else {
                        createDirtConnector(from: fromPoint, to: toPoint, name: connectionName)
                        dirtConnections += 1
                    }
                    
                    connectionsCreated += 1
                    print("🔗 Connected \(fromRoute) to \(toRoute) (\(Int(distance))km, \(type))")
                }
            }
        }
        
        print("✅ Created \(connectionsCreated) highway connections:")
        print("   - \(directConnections) routes already directly connected")
        print("   - \(pavedConnections) paved connectors")
        print("   - \(dirtConnections) dirt road connectors")
    }
    
    // MARK: - Create Paved Connector (Short Distance)
    
    private func createPavedConnector(from start: SCNVector3, to end: SCNVector3, name: String) {
        // Generate smooth path
        let path = generateSmoothConnectorPath(from: start, to: end, curveAmount: 0.3)
        
        // Convert to 2D points
        var points: [(CGFloat, CGFloat)] = []
        for point in path {
            points.append((point.x, point.z))
        }
        
        // Create road using the standard road creation system
        let roadNode = createSmoothRoadSegmentNode(points: points, routeName: name)
        roadNode.name = "connector_\(name)"
        
        scene.rootNode.addChildNode(roadNode)
    }
    
    // MARK: - Create Dirt Connector (Longer Distance)
    
    private func createDirtConnector(from start: SCNVector3, to end: SCNVector3, name: String) {
        // Use the existing dirt road system
        let path = generateTwistyDirtPath(from: start, to: end)
        createDirtRoadSegments(path: path, cityName: name)
    }
    
    // MARK: - Generate Smooth Connector Path
    
    private func generateSmoothConnectorPath(from start: SCNVector3, to end: SCNVector3, curveAmount: Float) -> [SCNVector3] {
        var controlPoints: [SCNVector3] = []
        
        // Add start point
        controlPoints.append(start)
        
        // Calculate direction
        let dx = end.x - start.x
        let dz = end.z - start.z
        let distance = sqrt(dx * dx + dz * dz)
        
        // Add control points for smooth curve
        let numControlPoints = 3
        for i in 1..<numControlPoints {
            let t = CGFloat(i) / CGFloat(numControlPoints)
            
            // Base position
            let baseX = start.x + dx * t
            let baseZ = start.z + dz * t
            
            // Add slight curve
            let perpX = -dz / distance
            let perpZ = dx / distance
            
            let curveOffset = sin(t * CGFloat.pi) * CGFloat(curveAmount) * distance
            
            let curveX = baseX + perpX * curveOffset
            let curveZ = baseZ + perpZ * curveOffset
            
            controlPoints.append(SCNVector3(curveX, 0, curveZ))
        }
        
        // Add end point
        controlPoints.append(end)
        
        // Generate smooth path using spline
        var smoothPath: [SCNVector3] = []
        let segmentsPerSection = 20
        
        for i in 0..<controlPoints.count - 1 {
            let p0 = i > 0 ? controlPoints[i-1] : controlPoints[i]
            let p1 = controlPoints[i]
            let p2 = controlPoints[i+1]
            let p3 = i < controlPoints.count - 2 ? controlPoints[i+2] : controlPoints[i+1]
            
            for j in 0..<segmentsPerSection {
                let t = Float(j) / Float(segmentsPerSection)
                let smoothPoint = catmullRomSpline(p0, p1, p2, p3, t)
                smoothPath.append(smoothPoint)
            }
        }
        
        // Add final point
        smoothPath.append(end)
        
        return smoothPath
    }
} 