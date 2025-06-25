//
//  GameViewController+Utilities.swift
//  Interstate
//
//  Utility functions for GPS conversion and calculations
//

import SceneKit
import Foundation

extension GameViewController {
    
    // MARK: - GPS Conversion
    
    func convertSceneToGPS(_ scenePosition: SCNVector3) -> (lat: Double, lon: Double) {
        // Convert from SceneKit coordinates back to GPS
        let metersEast = Double(scenePosition.x) / sceneScale
        let metersNorth = Double(-scenePosition.z) / sceneScale // Negative because +Z is south
        
        let deltaLat = metersNorth / latitudeScale
        let deltaLon = metersEast / longitudeScale
        
        let latitude = centerLatitude + deltaLat
        let longitude = centerLongitude + deltaLon
        
        return (lat: latitude, lon: longitude)
    }
    
    func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    }
    
    func gpsToSceneKit(latitude: Double, longitude: Double) -> SCNVector3 {
        // Convert GPS coordinates to meters from center
        let deltaLat = latitude - centerLatitude
        let deltaLon = longitude - centerLongitude
        
        // Convert to meters
        let metersNorth = deltaLat * latitudeScale
        let metersEast = deltaLon * longitudeScale
        
        // Apply scene scale and return as SCNVector3
        let x = Float(metersEast * sceneScale)
        let z = Float(-metersNorth * sceneScale)  // Negative because +Z is south in SceneKit
        
        return SCNVector3(CGFloat(x), 0, CGFloat(z))
    }
    
    // MARK: - Highway Detection
    
    func getCurrentHighway(position: SCNVector3) -> String {
        let carX = position.x
        let carZ = position.z
        var closestHighway = ""
        var minDistance: CGFloat = CGFloat.infinity
        
        // First check loaded road nodes (most accurate)
        for (routeName, nodes) in loadedRoadNodes {
            for node in nodes {
                let distance = sqrt(pow(carX - node.position.x, 2) + 
                                  pow(carZ - node.position.z, 2))
                
                if distance < minDistance {
                    minDistance = distance
                    closestHighway = routeName
                }
            }
        }
        
        // If we found a road within reasonable distance, use it
        if minDistance < 100.0 && !closestHighway.isEmpty {
            return closestHighway
        }
        
        // Otherwise check all GPS data to find nearest highway
        minDistance = CGFloat.infinity
        for (routeName, gpsCoordinates) in interstateRoutes {
            // Convert GPS to scene coordinates
            var sceneCoordinates: [(CGFloat, CGFloat)] = []
            for (lat, lon) in gpsCoordinates {
                let pos = gpsToSceneKit(latitude: lat, longitude: lon)
                sceneCoordinates.append((pos.x, pos.z))
            }
            
            // Check distance to each segment
            for i in 0..<sceneCoordinates.count-1 {
                let start = sceneCoordinates[i]
                let end = sceneCoordinates[i+1]
                
                let distanceToSegment = distanceToLineSegment(
                    point: (carX, carZ),
                    lineStart: start,
                    lineEnd: end
                )
                
                if distanceToSegment < minDistance {
                    minDistance = distanceToSegment
                    closestHighway = routeName
                }
            }
        }
        
        // Always return a highway name - even if far away
        return closestHighway.isEmpty ? "I-95" : closestHighway  // Default to I-95 if somehow nothing found
    }
    
    // MARK: - Distance Calculations
    
    func distanceToLineSegment(point: (CGFloat, CGFloat), lineStart: (CGFloat, CGFloat), lineEnd: (CGFloat, CGFloat)) -> CGFloat {
        let A = point.0 - lineStart.0
        let B = point.1 - lineStart.1
        let C = lineEnd.0 - lineStart.0
        let D = lineEnd.1 - lineStart.1
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        let param = dot / lenSq
        
        let xx, yy: CGFloat
        if param < 0 {
            xx = lineStart.0
            yy = lineStart.1
        } else if param > 1 {
            xx = lineEnd.0
            yy = lineEnd.1
        } else {
            xx = lineStart.0 + param * C
            yy = lineStart.1 + param * D
        }
        
        let dx = point.0 - xx
        let dy = point.1 - yy
        return sqrt(dx * dx + dy * dy)
    }
    
    func closestPointOnLineSegment(point: (CGFloat, CGFloat), lineStart: (CGFloat, CGFloat), lineEnd: (CGFloat, CGFloat)) -> (CGFloat, CGFloat) {
        let A = point.0 - lineStart.0
        let B = point.1 - lineStart.1
        let C = lineEnd.0 - lineStart.0
        let D = lineEnd.1 - lineStart.1
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        // Handle degenerate case where start and end are the same
        if lenSq < 0.0001 {
            return lineStart
        }
        
        let param = dot / lenSq
        
        let clampedParam = max(0, min(1, param))
        
        let closestX = lineStart.0 + clampedParam * C
        let closestY = lineStart.1 + clampedParam * D
        
        return (closestX, closestY)
    }
    
    // MARK: - Bezier Path Helpers
    
    func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func interpolate(from p1: CGPoint, to p2: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(x: p1.x + (p2.x - p1.x) * t,
                      y: p1.y + (p2.y - p1.y) * t)
    }
    
    func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let oneMinusTCubed = oneMinusTSquared * oneMinusT
        let tSquared = t * t
        let tCubed = tSquared * t
        
        let x = oneMinusTCubed * p0.x + 3 * oneMinusTSquared * t * p1.x + 
                3 * oneMinusT * tSquared * p2.x + tCubed * p3.x
        let y = oneMinusTCubed * p0.y + 3 * oneMinusTSquared * t * p1.y + 
                3 * oneMinusT * tSquared * p2.y + tCubed * p3.y
        
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Catmull-Rom Spline
    
    func catmullRomSpline(_ p0: SCNVector3, _ p1: SCNVector3, _ p2: SCNVector3, _ p3: SCNVector3, _ t: Float) -> SCNVector3 {
        let t2 = t * t
        let t3 = t2 * t
        
        let x = 0.5 * (2 * p1.x + (-p0.x + p2.x) * CGFloat(t) + 
                       (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * CGFloat(t2) + 
                       (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * CGFloat(t3))
        
        let y = 0.5 * (2 * p1.y + (-p0.y + p2.y) * CGFloat(t) + 
                       (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * CGFloat(t2) + 
                       (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * CGFloat(t3))
        
        let z = 0.5 * (2 * p1.z + (-p0.z + p2.z) * CGFloat(t) + 
                       (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * CGFloat(t2) + 
                       (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * CGFloat(t3))
        
        return SCNVector3(x, y, z)
    }
    
    // MARK: - Smooth Road Generation
    
    func generateSmoothRoadPoints(from gpsCoordinates: [(Double, Double)]) -> [(CGFloat, CGFloat)] {
        guard gpsCoordinates.count >= 2 else { return [] }
        
        // Convert GPS to scene coordinates
        var scenePoints: [SCNVector3] = []
        for (lat, lon) in gpsCoordinates {
            let pos = gpsToSceneKit(latitude: lat, longitude: lon)
            scenePoints.append(SCNVector3(pos.x, 0, pos.z))
        }
        
        var smoothPoints: [(CGFloat, CGFloat)] = []
        let segmentsPerSection = 50 // Greatly increased for much smoother curves
        
        for i in 0..<scenePoints.count - 1 {
            // Get control points (handle edge cases)
            let p0 = i > 0 ? scenePoints[i-1] : scenePoints[i]
            let p1 = scenePoints[i]
            let p2 = scenePoints[i+1]
            let p3 = i < scenePoints.count - 2 ? scenePoints[i+2] : scenePoints[i+1]
            
            // Generate smooth points between p1 and p2 using Catmull-Rom spline
            for j in 0..<segmentsPerSection {
                let t = Float(j) / Float(segmentsPerSection)
                let smoothPoint = catmullRomSpline(p0, p1, p2, p3, t)
                smoothPoints.append((smoothPoint.x, smoothPoint.z))
            }
        }
        
        // Add final point with proper smoothing
        if let lastPoint = scenePoints.last {
            smoothPoints.append((lastPoint.x, lastPoint.z))
        }
        
        return smoothPoints
    }
    
    // MARK: - Line Intersection
    
    func lineIntersection(p1: (CGFloat, CGFloat), p2: (CGFloat, CGFloat), p3: (CGFloat, CGFloat), p4: (CGFloat, CGFloat)) -> (CGFloat, CGFloat)? {
        let x1 = p1.0, y1 = p1.1
        let x2 = p2.0, y2 = p2.1
        let x3 = p3.0, y3 = p3.1
        let x4 = p4.0, y4 = p4.1
        
        let denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if abs(denom) < 0.0001 { return nil } // Lines are parallel
        
        let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        
        // Check if intersection is within both line segments
        if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
            let x = x1 + t * (x2 - x1)
            let y = y1 + t * (y2 - y1)
            return (x, y)
        }
        
        return nil
    }
}

// Extension to convert NSBezierPath to CGPath
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            default:
                break
            }
        }
        
        return path
    }
}