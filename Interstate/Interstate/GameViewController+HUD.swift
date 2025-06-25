//
//  GameViewController+HUD.swift
//  Interstate
//
//  HUD, UI elements, and radar map
//

import SceneKit
import AppKit
import QuartzCore

extension GameViewController {
    
    // MARK: - HUD Setup
    
    func setupHUD() {
        // Create HUD container - FORCE TOP-LEFT CORNER!
        let hudWidth: CGFloat = 520  // Wider for longer instructions
        let hudHeight: CGFloat = 120  // Taller for more info
        
        // Debug print to see what's happening
        print("View bounds: \(view.bounds)")
        print("View frame: \(view.frame)")
        
        // Calculate position for TOP-LEFT (high Y value in macOS coordinates)
        let hudX: CGFloat = 20
        let hudY: CGFloat = view.bounds.height - hudHeight - 20
        
        print("HUD Position: x=\(hudX), y=\(hudY)")
        
        hudContainer = NSView(frame: NSRect(x: hudX, y: hudY, width: hudWidth, height: hudHeight))
        hudContainer.wantsLayer = true
        hudContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor
        hudContainer.layer?.cornerRadius = 10
        hudContainer.layer?.borderColor = NSColor.cyan.withAlphaComponent(1.0).cgColor // CYAN border for visibility
        hudContainer.layer?.borderWidth = 5
        view.addSubview(hudContainer)
        
        // Speed label - TOP of HUD (high Y value in NSView coordinates)
        speedLabel = NSTextField(frame: NSRect(x: 10, y: 95, width: 500, height: 20))
        speedLabel.stringValue = "Speed: 0 mph"
        speedLabel.textColor = NSColor.white
        speedLabel.font = NSFont.boldSystemFont(ofSize: 14)
        speedLabel.backgroundColor = NSColor.clear
        speedLabel.isBordered = false
        speedLabel.isEditable = false
        hudContainer.addSubview(speedLabel)
        
        // Current route label - SECOND from top
        currentRouteLabel = NSTextField(frame: NSRect(x: 10, y: 77, width: 500, height: 18))
        currentRouteLabel.stringValue = "Current Route: Calculating..."
        currentRouteLabel.textColor = NSColor.green
        currentRouteLabel.font = NSFont.systemFont(ofSize: 12)
        currentRouteLabel.backgroundColor = NSColor.clear
        currentRouteLabel.isBordered = false
        currentRouteLabel.isEditable = false
        hudContainer.addSubview(currentRouteLabel)
        
        // Compass label - THIRD from top
        compassLabel = NSTextField(frame: NSRect(x: 10, y: 59, width: 500, height: 18))
        compassLabel.stringValue = "Heading: N"
        compassLabel.textColor = NSColor.systemBlue
        compassLabel.font = NSFont.systemFont(ofSize: 12)
        compassLabel.backgroundColor = NSColor.clear
        compassLabel.isBordered = false
        compassLabel.isEditable = false
        hudContainer.addSubview(compassLabel)
        
        // Segment count label for simple road loading system
        segmentCountLabel = NSTextField(frame: NSRect(x: 10, y: 41, width: 300, height: 18))
        segmentCountLabel.isEditable = false
        segmentCountLabel.isBordered = false
        segmentCountLabel.backgroundColor = NSColor.clear
        segmentCountLabel.textColor = NSColor.yellow
        segmentCountLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        segmentCountLabel.stringValue = "0/200 segments"
        hudContainer.addSubview(segmentCountLabel)
        
        // Score label - FOURTH from top  
        scoreLabel = NSTextField(frame: NSRect(x: 10, y: 23, width: 500, height: 18))
        scoreLabel.stringValue = "Score: 0 | High: \(highScore)"
        scoreLabel.textColor = NSColor.orange
        scoreLabel.font = NSFont.boldSystemFont(ofSize: 12)
        scoreLabel.backgroundColor = NSColor.clear
        scoreLabel.isBordered = false
        scoreLabel.isEditable = false
        hudContainer.addSubview(scoreLabel)
        
        // Time label - FIFTH from top
        timeLabel = NSTextField(frame: NSRect(x: 10, y: 5, width: 500, height: 18))
        timeLabel.stringValue = "Time: 0:00 | Checkpoints: 0"
        timeLabel.textColor = NSColor.magenta
        timeLabel.font = NSFont.systemFont(ofSize: 11)
        timeLabel.backgroundColor = NSColor.clear
        timeLabel.isBordered = false
        timeLabel.isEditable = false
        hudContainer.addSubview(timeLabel)
        
        // REMOVED - Instructions label was overlapping with time label
    }
    
    // MARK: - HUD Update
    
    func updateHUD() {
        let speedMph = Int(abs(carSpeed) * 2.237) // Convert m/s to mph approximation
        speedLabel.stringValue = "Speed: \(speedMph) mph"
        
        // Fix steering direction - positive angle = RIGHT, negative angle = LEFT
        let steeringDirection = steeringAngle > 0 ? "RIGHT" : steeringAngle < 0 ? "LEFT" : "STRAIGHT"
        let steeringInfo = abs(steeringAngle) > 0.1 ? " • Steering: \(steeringDirection)" : ""
        
        // Determine which highway the car is on
        let carPosition = carNode.position
        let currentHighway = getCurrentHighway(position: carPosition)
        
        // Calculate compass heading
        let heading = Float(carNode.eulerAngles.y)
        let compassDirection = getCompassDirection(heading: heading)
        let nearestCity = getNearestCity(position: carPosition)
        
        currentRouteLabel.stringValue = "Current Route: \(currentHighway)"
        compassLabel.stringValue = "Heading: \(compassDirection) • Next: \(nearestCity)"
        
        // Update score and timing information
        scoreLabel.stringValue = "Score: \(currentScore) | High: \(highScore)"
        
        if let gameStartTime = gameStartTime {
            let totalTime = Date().timeIntervalSince(gameStartTime)
            let minutes = Int(totalTime) / 60
            let seconds = Int(totalTime) % 60
            timeLabel.stringValue = "Time: \(minutes):\(String(format: "%02d", seconds)) | Checkpoints: \(checkpointsReached.count) | Controls: S=GAS W=BRAKE A=LEFT D=RIGHT"
        }
    }
    
    // MARK: - Radar Map Setup
    
    func setupRadarMap() {
        // Create radar container - TOP-RIGHT CORNER
        // TIGHT FIT around US map content
        let radarWidth: CGFloat = 200  // Much smaller - tight fit
        let radarHeight: CGFloat = 120  // Proportional to US map shape
        let radarX = view.bounds.width - radarWidth - 20
        let radarY = view.bounds.height - radarHeight - 20
        
        radarContainer = NSView(frame: NSRect(x: radarX, y: radarY, width: radarWidth, height: radarHeight))
        radarContainer.wantsLayer = true
        radarContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        radarContainer.layer?.cornerRadius = 10
        radarContainer.layer?.borderColor = NSColor.green.withAlphaComponent(1.0).cgColor
        radarContainer.layer?.borderWidth = 3
        view.addSubview(radarContainer)
        
        // Create radar map view with NO padding - fill the box
        radarMapView = NSView(frame: NSRect(x: 0, y: 0, width: radarWidth, height: radarHeight))
        radarMapView.wantsLayer = true
        radarContainer.addSubview(radarMapView)
        
        // Draw interstate highways on radar
        drawInterstateNetworkOnRadar()
        
        // Create pulsing car indicator
        createRadarCarIndicator()
    }
    
    func drawInterstateNetworkOnRadar() {
        let radarSize = radarMapView.frame.size
        let centerX = radarSize.width / 2
        let centerY = radarSize.height / 2
        
        // Create layer for unvisited roads (white)
        let roadLayer = CAShapeLayer()
        roadLayer.fillColor = NSColor.clear.cgColor
        roadLayer.strokeColor = NSColor.white.withAlphaComponent(0.5).cgColor
        roadLayer.lineWidth = 1.0
        
        let roadPath = CGMutablePath()
        
        // Draw all interstates
        for (_, gpsCoordinates) in interstateRoutes {
            var first = true
            for (lat, lon) in gpsCoordinates {
                let pos = gpsToSceneKit(latitude: lat, longitude: lon)
                let x = centerX + CGFloat(pos.x) * radarScale
                let y = centerY - CGFloat(pos.z) * radarScale  // Invert Y for display
                
                if first {
                    roadPath.move(to: CGPoint(x: x, y: y))
                    first = false
                } else {
                    roadPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        
        roadLayer.path = roadPath
        radarMapView.layer?.addSublayer(roadLayer)
        
        // Create layer for visited roads (green) - will be drawn in updateRadarMap
        let visitedLayer = CAShapeLayer()
        visitedLayer.fillColor = NSColor.clear.cgColor
        visitedLayer.strokeColor = NSColor.green.cgColor
        visitedLayer.lineWidth = 2.0
        visitedLayer.name = "visitedRoads"
        radarMapView.layer?.addSublayer(visitedLayer)
    }
    
    func createRadarCarIndicator() {
        // Create pulsing circle for car position
        radarCarLayer = CAShapeLayer()
        radarCarLayer.fillColor = NSColor.red.cgColor
        radarCarLayer.strokeColor = NSColor.white.cgColor
        radarCarLayer.lineWidth = 2.0
        
        let circlePath = NSBezierPath(ovalIn: NSRect(x: -4, y: -4, width: 8, height: 8))
        radarCarLayer.path = circlePath.cgPath
        
        radarMapView.layer?.addSublayer(radarCarLayer)
        
        // Add pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 0.8
        pulseAnimation.toValue = 1.5
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        radarCarLayer.add(pulseAnimation, forKey: "pulse")
    }
    
    // MARK: - Radar Map Update
    
    func updateRadarMap() {
        guard let radarMapView = radarMapView else { return }
        
        let radarSize = radarMapView.frame.size
        let centerX = radarSize.width / 2
        let centerY = radarSize.height / 2
        
        // Update car position on radar
        let carX = centerX + CGFloat(carNode.position.x) * radarScale
        let carY = centerY - CGFloat(carNode.position.z) * radarScale  // Invert Y
        
        radarCarLayer.position = CGPoint(x: carX, y: carY)
        
        // Add current position to trail
        let currentPoint = CGPoint(x: carX, y: carY)
        carTrail.append(currentPoint)
        
        // Update visited roads layer
        if let visitedLayer = radarMapView.layer?.sublayers?.first(where: { $0.name == "visitedRoads" }) as? CAShapeLayer {
            let visitedPath = CGMutablePath()
            
            if carTrail.count > 1 {
                visitedPath.move(to: carTrail[0])
                for i in 1..<carTrail.count {
                    visitedPath.addLine(to: carTrail[i])
                }
            }
            
            visitedLayer.path = visitedPath
        }
        
        // Add direction indicator
        if let directionLayer = radarMapView.layer?.sublayers?.first(where: { $0.name == "direction" }) {
            directionLayer.removeFromSuperlayer()
        }
        
        let directionLayer = CAShapeLayer()
        directionLayer.name = "direction"
        directionLayer.fillColor = NSColor.yellow.cgColor
        directionLayer.strokeColor = NSColor.clear.cgColor
        
        let heading = Float(carNode.eulerAngles.y)
        let dirX = sin(heading) * 10
        let dirZ = cos(heading) * 10
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: carX + CGFloat(dirX), y: carY - CGFloat(dirZ)))
        trianglePath.addLine(to: CGPoint(x: carX - CGFloat(dirX/2) + CGFloat(dirZ/2), y: carY + CGFloat(dirZ/2) + CGFloat(dirX/2)))
        trianglePath.addLine(to: CGPoint(x: carX - CGFloat(dirX/2) - CGFloat(dirZ/2), y: carY + CGFloat(dirZ/2) - CGFloat(dirX/2)))
        trianglePath.closeSubpath()
        
        directionLayer.path = trianglePath
        radarMapView.layer?.insertSublayer(directionLayer, below: radarCarLayer)
    }
    
    // MARK: - Layout Updates
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Update HUD position when view layout changes
        if let hud = hudContainer {
            let hudWidth: CGFloat = 520
            let hudHeight: CGFloat = 120
            let hudY = view.bounds.height - hudHeight - 20
            hud.frame = NSRect(x: 20, y: hudY, width: hudWidth, height: hudHeight)
            print("Updated HUD position in viewDidLayout: y=\(hudY), view height=\(view.bounds.height)")
        }
        
        // Update radar position
        if let radar = radarContainer {
            let radarWidth: CGFloat = 200
            let radarHeight: CGFloat = 120
            let radarX = view.bounds.width - radarWidth - 20
            let radarY = view.bounds.height - radarHeight - 20
            radar.frame = NSRect(x: radarX, y: radarY, width: radarWidth, height: radarHeight)
        }
    }
    
    // MARK: - HUD Helper Functions
    
    func getCompassDirection(heading: Float) -> String {
        // Convert SceneKit heading to compass degrees
        // In SceneKit movement code: 0 radians = +Z (south), π/2 = +X (east), π = -Z (north), 3π/2 = -X (west)
        // For compass: 0° = North, 90° = East, 180° = South, 270° = West
        
        var degrees = heading * 180 / Float.pi
        
        // Convert SceneKit coordinate system to standard compass
        // SceneKit 0° = South, so we need to subtract from 180° to get North as 0°
        degrees = 180 - degrees
        
        // Normalize to 0-360
        degrees = degrees.truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
        
        // Convert to compass direction
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", 
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        
        return "\(directions[index]) (\(Int(degrees))°)"
    }
    
    func getNearestCity(position: SCNVector3) -> String {
        // Simple approach: Find the nearest uncompleted checkpoint
        var nearestCheckpoint = ""
        var minDistance: CGFloat = CGFloat.infinity
        
        // First, try to find checkpoints that haven't been reached
        for (cityName, (checkpointPos, _)) in checkpointPositions {
            // Skip completed checkpoints
            if checkpointsReached.contains(cityName) { continue }
            
            // Calculate distance
            let distance = sqrt(pow(position.x - checkpointPos.x, 2) + 
                              pow(position.z - checkpointPos.z, 2))
            
            if distance < minDistance {
                minDistance = distance
                nearestCheckpoint = cityName
            }
        }
        
        // If all checkpoints are completed, just show the nearest one
        if nearestCheckpoint.isEmpty {
            for (cityName, (checkpointPos, _)) in checkpointPositions {
                let distance = sqrt(pow(position.x - checkpointPos.x, 2) + 
                                  pow(position.z - checkpointPos.z, 2))
                
                if distance < minDistance {
                    minDistance = distance
                    nearestCheckpoint = cityName
                }
            }
        }
        
        // Convert to miles and return - SAFETY CHECK for infinite/NaN values
        let distanceMiles: Int
        let distanceMeters = Double(minDistance) / sceneScale
        
        if minDistance.isFinite && !minDistance.isNaN && distanceMeters.isFinite {
            distanceMiles = Int(distanceMeters / 1609.34)
        } else {
            distanceMiles = 999 // Default fallback for invalid distances
        }
        
        return nearestCheckpoint.isEmpty ? "Unknown" : "→ \(nearestCheckpoint) (\(distanceMiles) mi)"
    }
    
    func getMemoryUsageStats() -> String {
        // Get data from SIMPLE road loading system - not the old complex system
        let segmentCount = loadedRoadSegments.count
        let maxSegments = 350 // User's requested limit
        let segmentWarning = segmentCount >= maxSegments ? " ⚠️MAX" : ""
        
        var totalRoutes = 0
        for (_, nodes) in loadedRoadNodes {
            if !nodes.isEmpty {
                totalRoutes += 1
            }
        }
        
        let loadedCheckpointCount = loadedCheckpoints.count
        
        return "Loaded: \(totalRoutes) routes, \(segmentCount)/\(maxSegments) segments\(segmentWarning), \(loadedCheckpointCount) checkpoints"
    }
}