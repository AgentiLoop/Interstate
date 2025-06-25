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
        // Pre-calculate checkpoint positions but don't create visual gates
        for (cityName, lat, lon, population) in majorCities {
            let cityPos = gpsToSceneKit(latitude: lat, longitude: lon)
            
            // For now, just use city positions directly - highway finding might be the issue
            checkpointPositions[cityName] = (cityPos, population)
        }
        
        // Test checkpoints removed - using only real city checkpoints now
        
        // Clean up checkpoints that are not near roads
        // DISABLED: This was causing checkpoints to swap positions
        // removeCheckpointsNotOnRoads()
    }
    
    // MARK: - Checkpoint Creation
    
    func createCheckpointGate(cityName: String, position: SCNVector3, population: Int) {
        // Get road direction to orient gate perpendicular to highway
        let roadDirection = getRoadDirectionAt(position: position)
        
        // Calculate perpendicular direction (90 degrees to road)
        let perpendicularAngle = roadDirection + Float.pi / 2
        
        // Calculate pole positions 15 units on each side of road
        let poleOffset: Float = 15.0
        let leftPoleX = position.x + CGFloat(cos(perpendicularAngle) * poleOffset)
        let leftPoleZ = position.z + CGFloat(sin(perpendicularAngle) * poleOffset)
        let rightPoleX = position.x - CGFloat(cos(perpendicularAngle) * poleOffset)
        let rightPoleZ = position.z - CGFloat(sin(perpendicularAngle) * poleOffset)
        
        // Gate poles
        let poleMaterial = SCNMaterial()
        poleMaterial.diffuse.contents = NSColor.white
        poleMaterial.emission.contents = NSColor(white: 0.2, alpha: 1.0)
        
        let poleGeometry = SCNCylinder(radius: 0.3, height: 12.0)
        poleGeometry.materials = [poleMaterial]
        
        // Left pole
        let leftPole = SCNNode(geometry: poleGeometry)
        leftPole.position = SCNVector3(leftPoleX, 6, leftPoleZ)
        leftPole.name = "pole_left_\(cityName)"
        scene.rootNode.addChildNode(leftPole)
        
        // Right pole
        let rightPole = SCNNode(geometry: poleGeometry)
        rightPole.position = SCNVector3(rightPoleX, 6, rightPoleZ)
        rightPole.name = "pole_right_\(cityName)"
        scene.rootNode.addChildNode(rightPole)
        
        // Banner connecting the poles - using pole positions directly
        let bannerMaterial = SCNMaterial()
        bannerMaterial.diffuse.contents = createBannerTexture(cityName: cityName)
        bannerMaterial.isDoubleSided = true
        
        // Calculate exact distance between poles
        let poleDistance = sqrt(pow(leftPoleX - rightPoleX, 2) + pow(leftPoleZ - rightPoleZ, 2))
        let bannerGeometry = SCNBox(width: CGFloat(poleDistance), height: 4, length: 0.2, chamferRadius: 0)
        bannerGeometry.materials = [bannerMaterial]
        
        let banner = SCNNode(geometry: bannerGeometry)
        banner.name = "banner_\(cityName)" // Add unique name to banner
        
        // Position at exact midpoint between poles
        let midX = (leftPoleX + rightPoleX) / 2
        let midZ = (leftPoleZ + rightPoleZ) / 2
        banner.position = SCNVector3(midX, 10, midZ)
        
        // Use look(at:) to orient banner from left pole to right pole
        let rightPolePosition = SCNVector3(rightPoleX, 10, rightPoleZ) 
        banner.look(at: rightPolePosition, up: SCNVector3(0, 1, 0), localFront: SCNVector3(1, 0, 0))
        
        scene.rootNode.addChildNode(banner)
        
        // Store checkpoint data for collision detection
        let checkpointNode = SCNNode()
        checkpointNode.name = "checkpoint_\(cityName)"
        checkpointNode.position = position
        scene.rootNode.addChildNode(checkpointNode)
    }
    
    func createBannerTexture(cityName: String, isCompleted: Bool = false) -> NSImage {
        // Create image size to match banner proportions (4:1 ratio)
        let imageSize = NSSize(width: 1024, height: 256)
        
        // Create image
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        // Fill with green or red background based on completion status
        if isCompleted {
            NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0).setFill() // Red for completed
        } else {
            NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0).setFill() // Green for uncompleted
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
        scene.rootNode.enumerateChildNodes { (node, _) in
            // Look for nodes with names containing this city's checkpoint
            if let nodeName = node.name,
               nodeName.contains("banner_\(cityName)") || nodeName.contains("checkpoint_\(cityName)") {
                // This is a node related to this checkpoint
                
                // If it's a banner node (has geometry), update it
                if let geometry = node.geometry as? SCNBox,
                   let material = geometry.firstMaterial {
                    // Change banner to red with "COMPLETED!" text - KEEP THE SAME CITY NAME
                    material.diffuse.contents = createBannerTexture(cityName: cityName, isCompleted: true)
                    print("🔴 Changed \(cityName) banner to red (completed)")
                }
            }
            
            // Also check for banner nodes by position but with tighter tolerance
            if let geometry = node.geometry as? SCNBox,
               let material = geometry.firstMaterial,
               node.position.y > 9.0 && node.position.y < 11.0 { // Banners are at y=10
                
                // Check if this banner is VERY close to the checkpoint
                if let (checkpointPos, _) = checkpointPositions[cityName] {
                    let distance = sqrt(pow(node.position.x - checkpointPos.x, 2) + 
                                      pow(node.position.z - checkpointPos.z, 2))
                    
                    // Much tighter distance check - only if banner is directly over checkpoint
                    if distance < 5.0 { // Within 5 units (was 50)
                        // Change banner to red with "COMPLETED!" text - KEEP THE SAME CITY NAME
                        material.diffuse.contents = createBannerTexture(cityName: cityName, isCompleted: true)
                        print("🔴 Changed \(cityName) banner to red (completed) - found by position")
                    }
                }
            }
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
            
            // Debug: Print every 60 frames (once per second at 60fps)
            var debugCounter = 0
            debugCounter += 1
            if debugCounter % 60 == 0 {
                print("🔍 Checkpoint update - Player at: \(playerPosition)")
                print("🔍 Available checkpoint positions: \(checkpointPositions.count)")
                print("🔍 Currently loaded checkpoints: \(loadedCheckpoints.count)")
            }
            
            var checkpointsToLoad: [String] = []
            var checkpointsToUnload: [String] = []
            
            // Check which checkpoints should be loaded/unloaded
            var debugCount = 0
            for (cityName, (checkpointPos, population)) in checkpointPositions {
                let distance = sqrt(pow(playerPosition.x - checkpointPos.x, 2) + 
                                  pow(playerPosition.z - checkpointPos.z, 2))
                
                let isLoaded = loadedCheckpoints[cityName] != nil
                
                // Debug for first few checkpoints
                if debugCounter % 60 == 0 && debugCount < 8 {
                    print("🔍 \(cityName): distance=\(Int(distance))m, loadDist=\(checkpointLoadDistance)m, loaded=\(isLoaded)")
                    debugCount += 1
                }
                
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
    
    func getRoadDirectionAt(position: SCNVector3) -> Float {
        var closestDirection: Float = 0.0
        var minDistance: CGFloat = CGFloat.infinity
        
        // Check all interstate routes to find the direction of the nearest road segment
        for (_, roadPoints) in allRoadPoints {
            // Check each segment of the route
            for i in 0..<roadPoints.count-1 {
                let start = roadPoints[i]
                let end = roadPoints[i+1]
                
                // Find closest point on this line segment
                let segmentPoint = closestPointOnLineSegment(
                    point: (position.x, position.z),
                    lineStart: start,
                    lineEnd: end
                )
                
                // Calculate distance to this segment
                let segmentPos = SCNVector3(segmentPoint.0, 0, segmentPoint.1)
                let distance = sqrt(pow(position.x - segmentPos.x, 2) + pow(position.z - segmentPos.z, 2))
                
                if distance < minDistance {
                    minDistance = distance
                    
                    // Calculate direction of this road segment
                    let deltaX = end.0 - start.0
                    let deltaZ = end.1 - start.1
                    closestDirection = atan2(Float(deltaZ), Float(deltaX))
                }
            }
        }
        
        return closestDirection
    }
    
    func removeCheckpointsNotOnRoads() {
        print("🔍 Cleaning up checkpoint data - moving checkpoints to nearest highways...")
        
        var checkpointsToRemove: [String] = []
        var checkpointsMoved = 0
        let maxDistanceToMove: CGFloat = 16093.0 // 10 miles in meters
        
        for (cityName, (checkpointPos, population)) in checkpointPositions {
            var closestHighwayPoint: SCNVector3?
            var minDistanceToRoad: CGFloat = CGFloat.infinity
            var closestRouteName: String = ""
            
            // Find the closest highway point across ALL interstate routes
            for (routeName, gpsCoordinates) in routeGPSData {
                for (lat, lon) in gpsCoordinates {
                    let routePoint = gpsToSceneKit(latitude: lat, longitude: lon)
                    let distance = sqrt(pow(checkpointPos.x - routePoint.x, 2) + 
                                      pow(checkpointPos.z - routePoint.z, 2))
                    
                    if distance < minDistanceToRoad {
                        minDistanceToRoad = distance
                        closestHighwayPoint = SCNVector3(routePoint.x, 0, routePoint.z)
                        closestRouteName = routeName
                    }
                }
            }
            
            if minDistanceToRoad <= maxDistanceToMove {
                if let highwayPoint = closestHighwayPoint {
                    // Check if this would create a duplicate position
                    var isDuplicate = false
                    for (otherCity, (otherPos, _)) in checkpointPositions {
                        if otherCity != cityName {
                            let distToOther = sqrt(pow(highwayPoint.x - otherPos.x, 2) + 
                                                 pow(highwayPoint.z - otherPos.z, 2))
                            if distToOther < 100.0 { // Within 100m of another checkpoint
                                isDuplicate = true
                                print("⚠️ \(cityName) would overlap with \(otherCity) at highway position")
                                break
                            }
                        }
                    }
                    
                    if !isDuplicate {
                        // Move checkpoint to the highway
                        checkpointPositions[cityName] = (highwayPoint, population)
                        checkpointsMoved += 1
                        print("📍 Moved \(cityName) to \(closestRouteName) highway (was \(Int(minDistanceToRoad))m away)")
                    } else {
                        print("⚠️ Keeping \(cityName) at original position to avoid overlap")
                    }
                } else {
                    print("✅ \(cityName) already on highway")
                }
            } else {
                // Too far from any highway - remove it
                checkpointsToRemove.append(cityName)
                print("❌ Removing \(cityName) - too far from highways (\(Int(minDistanceToRoad/1609))mi away)")
            }
        }
        
        // Remove checkpoints that are too far from any highway
        for cityName in checkpointsToRemove {
            checkpointPositions.removeValue(forKey: cityName)
        }
        
        print("🧹 Data cleanup completed:")
        print("   📍 Moved \(checkpointsMoved) checkpoints to highways")
        print("   ❌ Removed \(checkpointsToRemove.count) checkpoints (>10mi from highways)")
        print("   ✅ \(checkpointPositions.count) checkpoints now on highways")
    }
}
