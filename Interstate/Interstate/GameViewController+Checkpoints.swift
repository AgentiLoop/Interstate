//
//  GameViewController+Checkpoints.swift
//  Interstate
//
//  Checkpoint system and collision detection
//

import SceneKit
import AppKit
import Foundation

extension GameViewController {
    
    // MARK: - Checkpoint Setup
    
    func setupCheckpointGates() {
        // Store checkpoint positions EXACTLY at city positions - NEVER MOVE THEM
        for (cityName, lat, lon, population) in majorCities {
            let cityPos = gpsToSceneKit(latitude: lat, longitude: lon)
            
            // Store at exact city position - NO ROAD SNAPPING EVER
            checkpointPositions[cityName] = (cityPos, population)
            print("🏘️ Checkpoint \(cityName) positioned at city location: (\(Int(cityPos.x)), \(Int(cityPos.z)))")
        }
        
        print("✅ All \(checkpointPositions.count) checkpoints positioned at original city locations")
        
        // Analyze which checkpoints need dirt roads
        analyzeCheckpointDistances()
    }
    
    // MARK: - Checkpoint Creation
    
    func createCheckpointGate(cityName: String, position: SCNVector3, population: Int) {
        // NEVER MOVE CHECKPOINTS - always use original city position
        let checkpointPosition = position
        
        // Check if this checkpoint is near a highway to determine banner orientation
        let (nearestRoadPosition, roadDirection) = findNearestRoadPositionAndDirection(at: position)
        let distanceToRoad = sqrt(pow(position.x - nearestRoadPosition.x, 2) + pow(position.z - nearestRoadPosition.z, 2))
        let ONE_MILE_IN_METERS: CGFloat = 1609.34
        
        let isNearHighway = distanceToRoad < ONE_MILE_IN_METERS
        let bannerDirection = isNearHighway ? roadDirection : 0.0 // Default east-west if not near road
        
        if isNearHighway {
            print("📍 \(cityName) is near highway - orienting banner to highway direction (distance: \(Int(distanceToRoad))m)")
        } else {
            print("🏘️ \(cityName) is away from highway - using default east-west orientation (distance: \(Int(distanceToRoad))m)")
        }
        
        // Calculate perpendicular direction for banner (90 degrees to road direction or east-west)
        let perpendicularAngle = bannerDirection + CGFloat.pi / 2
        
        // Always use standard checkpoint width - no special highway treatment
        let poleOffset: CGFloat = 15.6
        let leftPoleX = checkpointPosition.x + cos(perpendicularAngle) * poleOffset
        let leftPoleZ = checkpointPosition.z + sin(perpendicularAngle) * poleOffset
        let rightPoleX = checkpointPosition.x - cos(perpendicularAngle) * poleOffset
        let rightPoleZ = checkpointPosition.z - sin(perpendicularAngle) * poleOffset
        
        // Gate poles - TALLER and BRIGHTER for visibility
        let poleMaterial = SCNMaterial()
        poleMaterial.diffuse.contents = NSColor.white
        poleMaterial.emission.contents = NSColor(white: 0.6, alpha: 1.0)
        
        let poleGeometry = SCNCylinder(radius: 0.5, height: 16.0)
        poleGeometry.materials = [poleMaterial]
        
        // Left pole
        let leftPole = SCNNode(geometry: poleGeometry)
        leftPole.position = SCNVector3(leftPoleX, 8, leftPoleZ)
        leftPole.name = "pole_left_\(cityName)"
        scene.rootNode.addChildNode(leftPole)
        
        // Right pole
        let rightPole = SCNNode(geometry: poleGeometry)
        rightPole.position = SCNVector3(rightPoleX, 8, rightPoleZ)
        rightPole.name = "pole_right_\(cityName)"
        scene.rootNode.addChildNode(rightPole)
        
        // Banner connecting the poles - using pole positions directly
        let bannerMaterial = SCNMaterial()
        let bannerTexture = createBannerTexture(cityName: cityName)
        bannerMaterial.diffuse.contents = bannerTexture
        bannerMaterial.emission.contents = bannerTexture // Use same texture for emission to glow with color
        bannerMaterial.emission.intensity = 0.3 // Control glow intensity
        bannerMaterial.isDoubleSided = true
        bannerMaterial.lightingModel = .constant // Always bright, unaffected by scene lighting
        
        // Calculate exact distance between poles
        let poleDistance = sqrt(pow(leftPoleX - rightPoleX, 2) + pow(leftPoleZ - rightPoleZ, 2))
        let bannerGeometry = SCNBox(width: poleDistance, height: 6.9, length: 0.3, chamferRadius: 0)
        bannerGeometry.materials = [bannerMaterial]
        
        let banner = SCNNode(geometry: bannerGeometry)
        banner.name = "banner_\(cityName)" // Add unique name to banner
        
        // Position at exact midpoint between poles - TOP OF BANNER MEETS TOP OF POLES
        let midX = (leftPoleX + rightPoleX) / 2.0
        let midZ = (leftPoleZ + rightPoleZ) / 2.0
        banner.position = SCNVector3(midX, 12.55, midZ)  // y=12.55 so top is at y=16 (same as pole tops)
        
        // Use look(at:) to orient banner from left pole to right pole
        let rightPolePosition = SCNVector3(rightPoleX, 12.55, rightPoleZ) 
        banner.look(at: rightPolePosition, up: SCNVector3(0, 1, 0), localFront: SCNVector3(1, 0, 0))
        
        scene.rootNode.addChildNode(banner)
        
        // Store checkpoint data for collision detection AT CORRECT POSITION
        let checkpointNode = SCNNode()
        checkpointNode.name = "checkpoint_\(cityName)"
        checkpointNode.position = checkpointPosition
        scene.rootNode.addChildNode(checkpointNode)
        
        // Also update the stored position for collision detection
        checkpointPositions[cityName] = (checkpointPosition, population)
    }
    
    func createBannerTexture(cityName: String, isCompleted: Bool = false) -> NSImage {
        // Create image size to match banner proportions (4:1 ratio)
        let imageSize = NSSize(width: 1024, height: 256)
        
        // Create image
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        // Fill with green or red background based on completion status
        if isCompleted {
            NSColor(red: 0.9, green: 0.0, blue: 0.0, alpha: 1.0).setFill() // Bright red for completed
        } else {
            NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0).setFill() // Bright green for uncompleted
        }
        NSRect(origin: .zero, size: imageSize).fill()
        
        // ALWAYS show "CHECKPOINT!" text at top - YELLOW, NO STROKE
        let titleText = "CHECKPOINT!" // NEVER CHANGE THIS TEXT
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 72),
            .foregroundColor: NSColor.yellow
        ]
        
        let titleString = NSAttributedString(string: titleText, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = NSRect(
            x: (imageSize.width - titleSize.width) / 2,
            y: imageSize.height - titleSize.height - 20,
            width: titleSize.width,
            height: titleSize.height
        )
        titleString.draw(in: titleRect)
        
        // Create city name text at bottom - WHITE, NO STROKE
        let cityAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 56),
            .foregroundColor: NSColor.white
        ]
        
        let cityString = NSAttributedString(string: cityName, attributes: cityAttributes)
        let citySize = cityString.size()
        let cityRect = NSRect(
            x: (imageSize.width - citySize.width) / 2,
            y: 30,
            width: citySize.width,
            height: citySize.height
        )
        cityString.draw(in: cityRect)
        
        image.unlockFocus()
        return image
    }
    
    func changeCheckpointBannerToRed(cityName: String) {
        // Find the specific banner node for this checkpoint and change it to red
        var bannerFound = false
        
        scene.rootNode.enumerateChildNodes { (node, _) in
            // Look for the banner node specifically
            if let nodeName = node.name, nodeName == "banner_\(cityName)" {
                // This is the banner for this checkpoint
                if let geometry = node.geometry as? SCNBox,
                   let material = geometry.firstMaterial {
                    // Change banner to red with completed texture
                    let redBannerTexture = createBannerTexture(cityName: cityName, isCompleted: true)
                    material.diffuse.contents = redBannerTexture
                    material.emission.contents = redBannerTexture
                    material.emission.intensity = 0.3
                    material.lightingModel = .constant
                    bannerFound = true
                    print("🔴 Changed \(cityName) banner to red (completed)")
                }
            }
        }
        
        // If we didn't find the banner by name, try to find it by proximity to checkpoint
        if !bannerFound {
            if let (checkpointPos, _) = checkpointPositions[cityName] {
                scene.rootNode.enumerateChildNodes { (node, _) in
                    // Look for banner geometry at the right height
                    if let geometry = node.geometry as? SCNBox,
                       let material = geometry.firstMaterial,
                       abs(node.position.y - 12.55) < 0.1 { // Banner height
                        
                        // Check if this banner is near the checkpoint
                        let distance = sqrt(pow(node.position.x - checkpointPos.x, 2) + 
                                          pow(node.position.z - checkpointPos.z, 2))
                        
                        // Within reasonable distance of checkpoint
                        if distance < 20.0 {
                            // Change banner to red
                            let redBannerTexture = createBannerTexture(cityName: cityName, isCompleted: true)
                            material.diffuse.contents = redBannerTexture
                            material.emission.contents = redBannerTexture
                            material.emission.intensity = 0.3
                            material.lightingModel = .constant
                            bannerFound = true
                            print("🔴 Changed \(cityName) banner to red (found by position)")
                        }
                    }
                }
            }
        }
        
        if !bannerFound {
            print("⚠️ Could not find banner for checkpoint: \(cityName)")
        }
    }
    
    // MARK: - Checkpoint Collision Detection
    
    func checkForCheckpointCollision() {
        guard let gameStartTime = gameStartTime else { return }
        
        let carPosition = carNode.position
        let speedMph = Int(abs(carSpeed) * 2.237) // Convert m/s to mph
        
        // Check loaded checkpoint positions (more efficient than searching scene)
        for (cityName, (checkpointPos, population)) in checkpointPositions {
            let distance = sqrt(pow(carPosition.x - checkpointPos.x, 2) + pow(carPosition.z - checkpointPos.z, 2))
            
            // Check if within checkpoint range, not already reached, and minimum speed requirement
            if distance < 25.0 && !checkpointsReached.contains(cityName) && speedMph >= 50 {
                // Checkpoint reached at valid speed!
                checkpointsReached.insert(cityName)
                
                let currentTime = Date().timeIntervalSince(gameStartTime)
                let checkpointTime = currentTime - lastCheckpointTime
                lastCheckpointTime = currentTime
                
                let points = calculateScore(population: population)
                currentScore += points
                
                print("🚩 CHECKPOINT: \(cityName) - \(points) points at \(speedMph) MPH!")
                print("⏱️ Time since last: \(String(format: "%.1f", checkpointTime))s")
                
                // Change checkpoint banner from green to red
                changeCheckpointBannerToRed(cityName: cityName)
                
                // Check for new high score
                if currentScore > highScore {
                    highScore = currentScore
                    saveHighScore()
                    print("🏆 NEW HIGH SCORE: \(highScore)!")
                }
            } else if distance < 25.0 && !checkpointsReached.contains(cityName) && speedMph < 50 {
                // Too slow - show warning
                print("⚠️ \(cityName) checkpoint missed - too slow! Need 50+ MPH (current: \(speedMph) MPH)")
            }
        }
    }
    
    // MARK: - Dynamic Checkpoint Loading    
    func updateDynamicCheckpoints() {
        autoreleasepool {
            let playerPosition = carNode.position
            
            // Debug: Print status occasionally
            // This debug logging is disabled in production
            
            var checkpointsToLoad: [String] = []
            var checkpointsToUnload: [String] = []
            
            // Check which checkpoints should be loaded/unloaded
            for (cityName, (checkpointPos, _)) in checkpointPositions {
                let distance = sqrt(pow(playerPosition.x - checkpointPos.x, 2) + 
                                  pow(playerPosition.z - checkpointPos.z, 2))
                
                let isLoaded = loadedCheckpoints[cityName] != nil
                
                if distance <= checkpointLoadDistance && !isLoaded {
                    checkpointsToLoad.append(cityName)
                    print("✅ Adding \(cityName) to load list (distance: \(Int(distance))m)")
                } else if distance > checkpointUnloadDistance && isLoaded {
                    checkpointsToUnload.append(cityName)
                }
            }
            
            // Load new checkpoints using existing createCheckpointGate function
            for cityName in checkpointsToLoad {
                autoreleasepool {
                    if let (position, population) = checkpointPositions[cityName] {
                        // Use the existing createCheckpointGate function that creates the visual signs!
                        createCheckpointGate(cityName: cityName, position: position, population: population)
                        
                        // Track that this checkpoint is loaded (find the actual checkpoint node created)
                        if let checkpointNode = scene.rootNode.childNode(withName: "checkpoint_\(cityName)", recursively: true) {
                            loadedCheckpoints[cityName] = checkpointNode
                            print("🚩 Loaded checkpoint: \(cityName)")
                        }
                    }
                }
            }
            
            // Unload distant checkpoints (remove all checkpoint components)
            for cityName in checkpointsToUnload {
                autoreleasepool {
                    if loadedCheckpoints[cityName] != nil {
                        // Remove all checkpoint-related nodes created by createCheckpointGate
                        scene.rootNode.enumerateChildNodes { (node, _) in
                            if let name = node.name, name.contains(cityName) && (name.contains("checkpoint") || name.contains("pole") || name.contains("banner")) {
                                node.removeFromParentNode()
                            }
                        }
                        
                        loadedCheckpoints.removeValue(forKey: cityName)
                        print("🧹 Unloaded checkpoint: \(cityName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func findNearestRoadPositionAndDirection(at position: SCNVector3) -> (SCNVector3, CGFloat) {
        var closestRoadPoint = position
        var closestDirection: CGFloat = 0.0
        var minDistance: CGFloat = CGFloat.infinity
        
        // Use the actual route GPS data to find road position and direction
        let routesToCheck = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        // Check all routes for the closest road segment
        for (_, gpsCoords) in routesToCheck {
            guard gpsCoords.count >= 2 else { continue }
            
            // Check each segment of the route
            for i in 0..<gpsCoords.count-1 {
                let startGPS = gpsCoords[i]
                let endGPS = gpsCoords[i+1]
                
                // Convert GPS to scene coordinates
                let startPos = gpsToSceneKit(latitude: startGPS.0, longitude: startGPS.1)
                let endPos = gpsToSceneKit(latitude: endGPS.0, longitude: endGPS.1)
                
                // Find closest point on this line segment
                let segmentPoint = closestPointOnLineSegment(
                    point: (position.x, position.z),
                    lineStart: (startPos.x, startPos.z),
                    lineEnd: (endPos.x, endPos.z)
                )
                
                // Calculate distance to this segment
                let segmentPos = SCNVector3(segmentPoint.0, 0, segmentPoint.1)
                let distance = sqrt(pow(position.x - segmentPos.x, 2) + pow(position.z - segmentPos.z, 2))
                
                if distance < minDistance {
                    minDistance = distance
                    closestRoadPoint = segmentPos
                    
                    // Calculate direction of this road segment
                    let deltaX = endPos.x - startPos.x
                    let deltaZ = endPos.z - startPos.z
                    closestDirection = atan2(CGFloat(deltaZ), CGFloat(deltaX))
                }
            }
        }
        
        // If no road found within 1 mile, use original position
        let ONE_MILE_IN_METERS: CGFloat = 1609.34
        if minDistance > ONE_MILE_IN_METERS {
            print("⚠️ No road found within 1 mile for checkpoint \(position)")
        }
        
        return (closestRoadPoint, closestDirection)
    }
    
    func findNearestRoadDirection(at position: SCNVector3) -> CGFloat {
        var closestDirection: CGFloat = 0.0
        var minDistance: CGFloat = CGFloat.infinity
        
        // Use the actual route GPS data to find road direction
        let routesToCheck = routeGPSData.isEmpty ? interstateRoutes : routeGPSData
        
        // Check all routes for the closest road segment
        for (_, gpsCoords) in routesToCheck {
            guard gpsCoords.count >= 2 else { continue }
            
            // Check each segment of the route
            for i in 0..<gpsCoords.count-1 {
                let startGPS = gpsCoords[i]
                let endGPS = gpsCoords[i+1]
                
                // Convert GPS to scene coordinates
                let startPos = gpsToSceneKit(latitude: startGPS.0, longitude: startGPS.1)
                let endPos = gpsToSceneKit(latitude: endGPS.0, longitude: endGPS.1)
                
                // Find closest point on this line segment
                let segmentPoint = closestPointOnLineSegment(
                    point: (position.x, position.z),
                    lineStart: (startPos.x, startPos.z),
                    lineEnd: (endPos.x, endPos.z)
                )
                
                // Calculate distance to this segment
                let segmentPos = SCNVector3(segmentPoint.0, 0, segmentPoint.1)
                let distance = sqrt(pow(position.x - segmentPos.x, 2) + pow(position.z - segmentPos.z, 2))
                
                if distance < minDistance {
                    minDistance = distance
                    
                    // Calculate direction of this road segment
                    let deltaX = endPos.x - startPos.x
                    let deltaZ = endPos.z - startPos.z
                    closestDirection = atan2(CGFloat(deltaZ), CGFloat(deltaX))
                }
            }
        }
        
        // If we found a road within reasonable distance, use its direction
        // Otherwise default to east-west (0 radians)
        let ONE_MILE_IN_METERS: CGFloat = 1609.34
        if minDistance > ONE_MILE_IN_METERS { // If no road within 1 mile, default to east-west
            closestDirection = 0.0
        }
        
        return closestDirection
    }
    
    func analyzeCheckpointDistances() {
        // DISABLED: This expensive analysis doesn't scale and isn't needed at startup
        // All checkpoints work fine without this analysis
        print("✅ Checkpoint analysis SKIPPED - all checkpoints work fine")
    }
    

    

    
    func updateCheckpointBannerColors() {
        // Update which cities show as red (50+ mph completed)
        for cityName in checkpointsReached {
            // Find nearest highway checkpoint
            if let (checkpointPos, _) = checkpointPositions[cityName] {
                var minDistance = CGFloat.infinity
                var closestDirection: CGFloat = 0.0
                
                // Look through all loaded routes to find closest approach
                for (routeName, gpsCoordinates) in interstateRoutes {
                    // Skip if this route isn't loaded
                    guard !gpsCoordinates.isEmpty else { continue }
                    
                    // Convert GPS coords to scene positions
                    for i in 0..<gpsCoordinates.count-1 {
                        let pos1 = gpsToSceneKit(latitude: gpsCoordinates[i].0, longitude: gpsCoordinates[i].1)
                        let pos2 = gpsToSceneKit(latitude: gpsCoordinates[i+1].0, longitude: gpsCoordinates[i+1].1)
                        
                        // Calculate distance from checkpoint to this road segment
                        let segmentVec = SCNVector3(pos2.x - pos1.x, 0, pos2.z - pos1.z)
                        let toCheckpoint = SCNVector3(checkpointPos.x - pos1.x, 0, checkpointPos.z - pos1.z)
                        
                        let segmentLength = sqrt(segmentVec.x * segmentVec.x + segmentVec.z * segmentVec.z)
                        if segmentLength > 0.1 {
                            let t = max(0, min(1, (toCheckpoint.x * segmentVec.x + toCheckpoint.z * segmentVec.z) / (segmentLength * segmentLength)))
                            let closestPoint = SCNVector3(pos1.x + segmentVec.x * t, 0, pos1.z + segmentVec.z * t)
                            
                            let deltaX = checkpointPos.x - closestPoint.x
                            let deltaZ = checkpointPos.z - closestPoint.z
                            let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
                            
                            let ONE_MILE_IN_METERS: CGFloat = 1609.34
                            if distance < minDistance && distance < ONE_MILE_IN_METERS { // Within 1 mile of highway
                                minDistance = distance
                                // Calculate direction of road at this point
                                closestDirection = atan2(CGFloat(deltaZ), CGFloat(deltaX))
                            }
                        }
                    }
                }
                
                // If we found a nearby road segment
                let ONE_MILE_IN_METERS: CGFloat = 1609.34
                if minDistance < ONE_MILE_IN_METERS {
                    changeCheckpointBannerToRed(cityName: cityName)
                }
            }
        }
    }
}
