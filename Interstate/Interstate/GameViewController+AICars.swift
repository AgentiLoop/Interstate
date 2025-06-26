//
//  GameViewController+AICars.swift
//  Interstate
//
//  AI cars system with collision detection and spin-out physics
//

import SceneKit
import Foundation

extension GameViewController {
    
    // MARK: - Player Path Tracking
    struct PathPoint {
        let position: SCNVector3
        let heading: CGFloat
        let speed: CGFloat
        let timestamp: TimeInterval
    }
    
    // MARK: - AI Car Initialization
    
    func setupAICars() {
        // Initialize AI cars array
        aiCars = []
        
        // Initialize player path tracking
        playerPath = []
        lastPathUpdateTime = CACurrentMediaTime()
        
        // Spawn EXACTLY 4 AI cars that follow the player
        for i in 0..<4 {
            // Add delay between spawns to space them out
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) { [weak self] in
                self?.spawnAICar(carIndex: i)
                print("🚗 Spawned AI car #\(i+1)")
            }
        }
        
        print("🚗 AI Car system initialized with 4 ghost cars following the player")
    }
    
    // MARK: - AI Car Creation
    
    func createAICarNode(color: NSColor) -> SCNNode {
        // Create a new car with the specified color
        let aiCarContainer = createCarNode(color: color)
        aiCarContainer.name = "aiCar"
        
        // Rename wheels for AI car tracking
        var wheelIndex = 0
        aiCarContainer.enumerateChildNodes { (node, _) in
            if let name = node.name, name.hasPrefix("wheel_") {
                node.name = "ai_wheel_\(wheelIndex)"
                wheelIndex += 1
            }
        }
        
        return aiCarContainer
    }
    
    // MARK: - AI Car Spawning
    
    func spawnAICar(carIndex: Int) {
        // Don't spawn more than max
        guard aiCars.count < maxAICars else { return }
        
        // Make sure each AI car gets a different color
        let color = aiCarColors[carIndex % aiCarColors.count]
        
        // Assign personality based on index
        let personality: AICarPersonality
        switch carIndex {
        case 0:
            personality = .chaser      // Yellow - Direct pursuit
        case 1:
            personality = .interceptor // Green - Get ahead
        case 2:
            personality = .racer       // Orange - Speed demon
        case 3:
            personality = .wanderer    // Magenta - Unpredictable
        default:
            personality = .chaser
        }
        
        print("🎨 Creating AI car #\(carIndex+1) with color: R:\(color.redComponent), G:\(color.greenComponent), B:\(color.blueComponent) and personality: \(personality)")
        
        let carNode = createAICarNode(color: color)
        
        // Spawn at random distance between 10-25 miles from player
        let playerPos = self.carNode.position
        let playerHeading = CGFloat(self.carNode.eulerAngles.y)
        
        // Convert miles to game units (1 mile = 1609.34 meters, 1 meter = 0.01 game units)
        let minDistanceMiles: CGFloat = 25.0  // Spawn between 25-75 miles
        let maxDistanceMiles: CGFloat = 75.0
        let minDistance: CGFloat = minDistanceMiles * 1609.34 * 0.01 // ~402 units
        let maxDistance: CGFloat = maxDistanceMiles * 1609.34 * 0.01 // ~1207 units
        
        // Random distance between min and max
        let spawnDistance = CGFloat.random(in: minDistance...maxDistance)
        
        // Random angle around the player (0 to 2π)
        let randomAngle = CGFloat.random(in: 0...(2 * CGFloat.pi))
        
        // Calculate spawn position
        let spawnX = playerPos.x + CGFloat(sin(randomAngle) * spawnDistance)
        let spawnZ = playerPos.z + CGFloat(cos(randomAngle) * spawnDistance)
        
        // Find the nearest road to the spawn position
        let spawnPos = SCNVector3(spawnX, 0, spawnZ)
        let nearestRoad = findNearestRoad(to: spawnPos)
        
        // Place car on the nearest road
        carNode.position = SCNVector3(nearestRoad.position.x, 1.1, nearestRoad.position.z)
        carNode.eulerAngles.y = CGFloat(nearestRoad.heading)
        
        // Create AI car data with physics properties
        let aiCar = AICar(
            node: carNode,
            currentSpeed: CGFloat.random(in: 50...70), // Start with some speed
            targetSpeed: 75.0,
            routeName: nearestRoad.routeName,
            routePointIndex: 0,
            positionOnSegment: 0,
            lane: 0,
            color: color,
            isSpinning: false,
            spinRotation: 0.0,
            isGoingForward: true,
            pathTargetIndex: 0, // Start following from beginning of path
            steeringAngle: 0.0, // Current steering angle
            wheelBase: 4.0, // Distance between front and rear axles
            isFleeing: false,
            fleeStartTime: 0,
            personality: personality,
            hasPassedPlayer: false
        )
        
        aiCars.append(aiCar)
        scene.rootNode.addChildNode(carNode)
        
        print("🚗 Spawned AI car #\(carIndex+1) at distance: \(spawnDistance) units (\(spawnDistance / (1609.34 * 0.01)) miles)")
    }
    
    // MARK: - Helper function to find nearest road
    
    struct RoadInfo {
        let position: SCNVector3
        let heading: CGFloat
        let routeName: String
    }
    
    func findNearestRoad(to position: SCNVector3) -> RoadInfo {
        var nearestRoad = RoadInfo(position: position, heading: 0, routeName: "")
        var minDistance = CGFloat.infinity
        
        // Search through all loaded routes
        for (routeName, points) in interstateRoutes {
            guard points.count >= 2 else { continue }
            
            for i in 0..<points.count-1 {
                let p1 = points[i]
                let p2 = points[i+1]
                
                let pos1 = gpsToSceneKit(latitude: p1.0, longitude: p1.1)
                let pos2 = gpsToSceneKit(latitude: p2.0, longitude: p2.1)
                
                // Find closest point on segment
                let segmentVec = SCNVector3(pos2.x - pos1.x, 0, pos2.z - pos1.z)
                let toPoint = SCNVector3(position.x - pos1.x, 0, position.z - pos1.z)
                
                let segmentLengthSq = CGFloat(segmentVec.x * segmentVec.x + segmentVec.z * segmentVec.z)
                if segmentLengthSq > 0 {
                    let dotProduct = CGFloat(toPoint.x * segmentVec.x + toPoint.z * segmentVec.z)
                    let t = max(0, min(1, dotProduct / segmentLengthSq))
                    
                    let closestPoint = SCNVector3(
                        pos1.x + segmentVec.x * CGFloat(t),
                        0,
                        pos1.z + segmentVec.z * CGFloat(t)
                    )
                
                    let dist = sqrt(pow(CGFloat(position.x - closestPoint.x), 2) + 
                                   pow(CGFloat(position.z - closestPoint.z), 2))
                    
                    if dist < minDistance {
                        minDistance = dist
                        
                        // Calculate heading of this road segment
                        let heading = atan2(CGFloat(pos2.x - pos1.x), CGFloat(pos2.z - pos1.z))
                        
                        nearestRoad = RoadInfo(
                            position: SCNVector3(closestPoint.x, 1.1, closestPoint.z),
                            heading: heading,
                            routeName: routeName
                        )
                    }
                }
            }
        }
        
        return nearestRoad
    }
    
    // MARK: - Path Recording
    
    func recordPlayerPath() {
        let currentTime = CACurrentMediaTime()
        
        // Record path point every 0.1 seconds
        if currentTime - lastPathUpdateTime > 0.1 {
            let pathPoint = PathPoint(
                position: carNode.position,
                heading: CGFloat(carNode.eulerAngles.y),
                speed: carSpeed,
                timestamp: currentTime
            )
            
            playerPath.append(pathPoint)
            lastPathUpdateTime = currentTime
            
            // Keep only last 1000 points (about 100 seconds of path)
            if playerPath.count > 1000 {
                playerPath.removeFirst()
            }
        }
    }
    
    // MARK: - AI Car Updates
    
    func updateAICars() {
        // First, record the player's current position
        recordPlayerPath()
        
        // Update each AI car
        for i in 0..<aiCars.count {
            var aiCar = aiCars[i]
            
            // Update AI car movement
            if !aiCar.isSpinning {
                updateAICarMovement(&aiCar)
            } else {
                updateAICarSpin(&aiCar)
            }
            
            // Check for collision with player
            if !isPlayerSpinning && !aiCar.isSpinning {
                checkAICarCollision(aiCar)
            }
            
            aiCars[i] = aiCar
        }
        
        // Update player spin if needed
        if isPlayerSpinning {
            updatePlayerSpin()
        }
        
        // Check if any AI cars need to be respawned (too far away)
        checkAndRespawnDistantAICars()
    }
    
    func updateAICarMovement(_ aiCar: inout AICar) {
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Check if car is fleeing
        if aiCar.isFleeing {
            let currentTime = CACurrentMediaTime()
            let fleeElapsed = currentTime - aiCar.fleeStartTime
            
            // Flee for 10 seconds
            if fleeElapsed > 10.0 {
                aiCar.isFleeing = false
                
                // Calculate distance reached
                let playerPos = carNode.position
                let distanceToPlayer = sqrt(pow(CGFloat(aiCar.node.position.x - playerPos.x), 2) + 
                                           pow(CGFloat(aiCar.node.position.z - playerPos.z), 2))
                let distanceMiles = distanceToPlayer / (1609.34 * 0.01)
                
                print("🏃 AI car stopped fleeing after 10 seconds, reached \(Int(distanceMiles)) miles away")
            } else {
                // Continue fleeing
                updateAICarFleeing(&aiCar)
                updateAICarWheels(&aiCar)
                return
            }
        }
        
        // FIRST: Always make sure AI car is on a road
        ensureAICarOnRoad(&aiCar)
        
        // Update based on personality
        switch aiCar.personality {
        case .chaser:
            updateAICarChaser(&aiCar)
        case .interceptor:
            updateAICarInterceptor(&aiCar)
        case .racer:
            updateAICarRacer(&aiCar)
        case .wanderer:
            updateAICarWanderer(&aiCar)
        }
        
        // Update wheels
        updateAICarWheels(&aiCar)
    }
    
    // MARK: - Road Following Functions
    
    func ensureAICarOnRoad(_ aiCar: inout AICar) {
        // Find the closest road point
        let nearestRoad = findNearestRoad(to: aiCar.node.position)
        
        // If car is too far from road, snap it back
        let distanceFromRoad = sqrt(pow(CGFloat(aiCar.node.position.x - nearestRoad.position.x), 2) + 
                                   pow(CGFloat(aiCar.node.position.z - nearestRoad.position.z), 2))
        
        if distanceFromRoad > 10.0 { // More than 10 units off road
            // Smoothly move back to road
            let snapFactor: CGFloat = 0.1
            aiCar.node.position.x = aiCar.node.position.x + CGFloat((CGFloat(nearestRoad.position.x) - CGFloat(aiCar.node.position.x)) * snapFactor)
            aiCar.node.position.z = aiCar.node.position.z + CGFloat((CGFloat(nearestRoad.position.z) - CGFloat(aiCar.node.position.z)) * snapFactor)
        }
        
        // Update current road
        aiCar.routeName = nearestRoad.routeName
    }
    
    // MARK: - Personality Behaviors (Updated for Road Following)
    
    func updateAICarChaser(_ aiCar: inout AICar) {
        // Yellow car - Follows player on roads
        let playerPos = carNode.position
        let playerHighway = getCurrentHighway(position: playerPos)
        
        if aiCar.routeName == playerHighway {
            // Same road as player - follow along road toward player
            followRoadTowardTarget(&aiCar, targetPos: playerPos, speed: 85.0)
        } else {
            // Different road - navigate highway system
            navigateToPlayerRoad(&aiCar)
        }
    }
    
    func updateAICarInterceptor(_ aiCar: inout AICar) {
        // Green car - Tries to get ahead on the road
        let playerPos = carNode.position
        let playerHeading = CGFloat(carNode.eulerAngles.y)
        let playerSpeed = carSpeed
        
        // Predict where player will be
        let predictionTime: CGFloat = 4.0
        let predictedDistance = playerSpeed * predictionTime
        let predictedX = playerPos.x + CGFloat(sin(playerHeading) * predictedDistance)
        let predictedZ = playerPos.z + CGFloat(cos(playerHeading) * predictedDistance)
        let predictedPos = SCNVector3(predictedX, 0, predictedZ)
        
        followRoadTowardTarget(&aiCar, targetPos: predictedPos, speed: 95.0)
    }
    
    func updateAICarRacer(_ aiCar: inout AICar) {
        // Orange car - Races ahead on the road
        if !aiCar.hasPassedPlayer {
            // Try to pass by going fast
            let playerPos = carNode.position
            followRoadTowardTarget(&aiCar, targetPos: playerPos, speed: 110.0)
            
            // Check if we've passed
            let dx = CGFloat(aiCar.node.position.x - playerPos.x)
            let dz = CGFloat(aiCar.node.position.z - playerPos.z)
            let playerHeading = CGFloat(carNode.eulerAngles.y)
            let relativeAngle = atan2(dx, dz) - playerHeading
            let isAhead = cos(relativeAngle) > 0
            
            if isAhead {
                aiCar.hasPassedPlayer = true
            }
        } else {
            // Stay ahead by following road at high speed
            followRoadForward(&aiCar, speed: max(carSpeed + 20, 90.0))
        }
    }
    
    func updateAICarWanderer(_ aiCar: inout AICar) {
        // Magenta car - Varied behavior
        let currentTime = CACurrentMediaTime()
        let behaviorCycle = Int(currentTime / 15.0) % 3
        
        switch behaviorCycle {
        case 0:
            // Follow player on roads
            updateAICarChaser(&aiCar)
        case 1:
            // Just cruise on current road
            followRoadForward(&aiCar, speed: 75.0)
        case 2:
            // Try to intercept
            updateAICarInterceptor(&aiCar)
        default:
            followRoadForward(&aiCar, speed: 80.0)
        }
    }
    
    // MARK: - Road Following Movement
    
    func followRoadTowardTarget(_ aiCar: inout AICar, targetPos: SCNVector3, speed: CGFloat) {
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Get current road segment
        guard let routePoints = interstateRoutes[aiCar.routeName],
              routePoints.count >= 2 else {
            // No valid road - find one
            ensureAICarOnRoad(&aiCar)
            return
        }
        
        // Find next waypoint on road toward target
        let nextWaypoint = findNextWaypointTowardTarget(aiCar: aiCar, targetPos: targetPos, routePoints: routePoints)
        
        // Calculate smooth path to next waypoint
        let dx = CGFloat(nextWaypoint.x - aiCar.node.position.x)
        let dz = CGFloat(nextWaypoint.z - aiCar.node.position.z)
        let distanceToWaypoint = sqrt(dx * dx + dz * dz)
        
        if distanceToWaypoint < 5.0 {
            // Close to waypoint - advance to next segment
            aiCar.routePointIndex = (aiCar.routePointIndex + 1) % (routePoints.count - 1)
        }
        
        // Calculate desired heading along road
        let desiredHeading = atan2(dx, dz)
        let currentHeading = CGFloat(aiCar.node.eulerAngles.y)
        
        // Smooth heading adjustment
        var headingDiff = desiredHeading - currentHeading
        while headingDiff > CGFloat.pi { headingDiff -= 2 * CGFloat.pi }
        while headingDiff < -CGFloat.pi { headingDiff += 2 * CGFloat.pi }
        
        // VERY SMOOTH steering for road following
        let maxSteeringAngle: CGFloat = 0.3 // Reduced for smoother road following
        let steeringRate: CGFloat = 2.0 // Smooth steering rate
        
        aiCar.steeringAngle = max(-maxSteeringAngle, min(maxSteeringAngle, headingDiff * 0.5))
        
        // Apply steering physics
        if abs(speed) > 0.1 {
            let turningRadius = aiCar.wheelBase / tan(abs(aiCar.steeringAngle) + 0.001)
            let angularVelocity = speed / turningRadius
            aiCar.node.eulerAngles.y += CGFloat(angularVelocity * deltaTime * (aiCar.steeringAngle > 0 ? 1 : -1))
        }
        
        // Smooth speed control
        let targetSpeed = speed
        let maxAcceleration: CGFloat = 30.0
        let maxBraking: CGFloat = 40.0
        
        let speedDiff = targetSpeed - aiCar.currentSpeed
        if speedDiff > 0 {
            aiCar.currentSpeed += min(speedDiff, maxAcceleration * deltaTime)
        } else {
            aiCar.currentSpeed += max(speedDiff, -maxBraking * deltaTime)
        }
        
        // Move forward along heading
        let moveDistance = aiCar.currentSpeed * deltaTime
        let carHeading = CGFloat(aiCar.node.eulerAngles.y)
        
        aiCar.node.position.x += CGFloat(sin(carHeading) * moveDistance)
        aiCar.node.position.z += CGFloat(cos(carHeading) * moveDistance)
        aiCar.node.position.y = 1.1
    }
    
    func followRoadForward(_ aiCar: inout AICar, speed: CGFloat) {
        // Just follow the current road forward
        guard let routePoints = interstateRoutes[aiCar.routeName],
              routePoints.count >= 2 else {
            ensureAICarOnRoad(&aiCar)
            return
        }
        
        let segmentIndex = min(aiCar.routePointIndex, routePoints.count - 2)
        let nextIndex = segmentIndex + 1
        
        let currentPoint = routePoints[segmentIndex]
        let nextPoint = routePoints[nextIndex]
            
        let pos1 = gpsToSceneKit(latitude: currentPoint.0, longitude: currentPoint.1)
        let pos2 = gpsToSceneKit(latitude: nextPoint.0, longitude: nextPoint.1)
            
        // Follow to next point
        followRoadTowardTarget(&aiCar, targetPos: pos2, speed: speed)
    }
    
    func findNextWaypointTowardTarget(aiCar: AICar, targetPos: SCNVector3, routePoints: [(Double, Double)]) -> SCNVector3 {
        // Get current and next road points
        let segmentIndex = min(aiCar.routePointIndex, routePoints.count - 2)
        let nextIndex = segmentIndex + 1
        
        let currentPoint = routePoints[segmentIndex]
        let nextPoint = routePoints[nextIndex]
        
        let pos1 = gpsToSceneKit(latitude: currentPoint.0, longitude: currentPoint.1)
        let pos2 = gpsToSceneKit(latitude: nextPoint.0, longitude: nextPoint.1)
        
        // For now, just aim for the next point on the road
        // This ensures we follow the road geometry
        return pos2
    }
    
    func navigateToPlayerRoad(_ aiCar: inout AICar) {
        // Find route to player's road using highway connections
        let playerPos = carNode.position
        let playerHighway = getCurrentHighway(position: playerPos)
                
        if let connections = highwayConnections[aiCar.routeName] {
            // Check if any connection leads to player's highway
            for (connectedHighway, _, _) in connections {
                if connectedHighway == playerHighway {
                    // Find the connection point between the two highways
                    if let connectionPoint = findConnectionPoint(from: aiCar.routeName, to: connectedHighway) {
                        // Head toward connection point
                        followRoadTowardTarget(&aiCar, targetPos: connectionPoint, speed: 90.0)
                        return
                    }
                }
            }
        }
        
        // No direct connection - just follow current road
        followRoadForward(&aiCar, speed: 85.0)
    }
    
    func findConnectionPoint(from fromRoute: String, to toRoute: String) -> SCNVector3? {
        // Find where two highways connect
        guard let fromCoords = interstateRoutes[fromRoute],
              let toCoords = interstateRoutes[toRoute],
              !fromCoords.isEmpty,
              !toCoords.isEmpty else { return nil }
        
        var minDist = CGFloat.infinity
        var connectionPoint: SCNVector3?
        
        // Check endpoints and some midpoints
        let fromPoints = [
            gpsToSceneKit(latitude: fromCoords.first!.0, longitude: fromCoords.first!.1),
            gpsToSceneKit(latitude: fromCoords.last!.0, longitude: fromCoords.last!.1)
        ]
        
        let toPoints = [
            gpsToSceneKit(latitude: toCoords.first!.0, longitude: toCoords.first!.1),
            gpsToSceneKit(latitude: toCoords.last!.0, longitude: toCoords.last!.1)
        ]
        
        // Find closest points
        for fromPoint in fromPoints {
            for toPoint in toPoints {
                let dist = sqrt(pow(CGFloat(fromPoint.x - toPoint.x), 2) + 
                               pow(CGFloat(fromPoint.z - toPoint.z), 2))
                if dist < minDist {
                    minDist = dist
                    // Use the midpoint as the connection point
                    connectionPoint = SCNVector3(
                        (fromPoint.x + toPoint.x) / 2,
                        0,
                        (fromPoint.z + toPoint.z) / 2
                    )
                }
            }
        }
        
        return connectionPoint
    }
    
    // MARK: - Collision Detection
    
    func checkAICarCollision(_ aiCar: AICar) {
        let playerPos = carNode.position
        let aiPos = aiCar.node.position
        
        // Calculate distance
        let distance = sqrt(pow(CGFloat(playerPos.x - aiPos.x), 2) + 
                          pow(CGFloat(playerPos.z - aiPos.z), 2))
        
        // Check for collision (slightly larger collision distance for realism)
        if distance < collisionDistance * 1.2 {
            // Calculate collision angle
            let collisionAngle = atan2(CGFloat(aiPos.x - playerPos.x), CGFloat(aiPos.z - playerPos.z))
            let playerHeading = CGFloat(carNode.eulerAngles.y)
            
            // Determine spin direction based on collision angle
            var angleDiff = collisionAngle - playerHeading
            while angleDiff > CGFloat.pi { angleDiff -= 2 * CGFloat.pi }
            while angleDiff < -CGFloat.pi { angleDiff += 2 * CGFloat.pi }
            
            // Trigger player spin-out
            isPlayerSpinning = true
            playerSpinVelocity = (angleDiff > 0) ? 12.0 : -12.0 // Spin direction based on impact
            
            // Play crash sound effect
            handleCrashAudio()
            
            // Make AI car start fleeing for 10 seconds
            if let index = aiCars.firstIndex(where: { $0.node == aiCar.node }) {
                aiCars[index].isFleeing = true
                aiCars[index].fleeStartTime = CACurrentMediaTime()
                
                print("💥 Collision! AI car fleeing at extreme speed for 10 seconds (targeting 100-150 miles away)")
            }
            
            print("💥 Collision detected! Player spinning, AI car fleeing!")
        }
    }
    
    func updatePlayerSpin() {
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Spin the car with physics
        playerSpinAngle += playerSpinVelocity * deltaTime
        carNode.eulerAngles.y += CGFloat(playerSpinVelocity * deltaTime)
        
        // Reduce car speed dramatically but keep some momentum
        let brakingForce: CGFloat = 50.0
        carSpeed = max(0, carSpeed - brakingForce * deltaTime)
        
        // Move slightly while spinning (conservation of momentum)
        let moveDistance = carSpeed * deltaTime * 0.3
        let spinHeading = CGFloat(carNode.eulerAngles.y)
        carNode.position.x += CGFloat(sin(spinHeading) * moveDistance)
        carNode.position.z += CGFloat(cos(spinHeading) * moveDistance)
        
        // Reduce spin velocity (friction)
        let friction: CGFloat = 5.0
        if playerSpinVelocity > 0 {
            playerSpinVelocity = max(0, playerSpinVelocity - friction * deltaTime)
        } else {
            playerSpinVelocity = min(0, playerSpinVelocity + friction * deltaTime)
        }
        
        // Stop spinning when velocity is low
        if abs(playerSpinVelocity) < 0.5 {
            isPlayerSpinning = false
            playerSpinVelocity = 0
            playerSpinAngle = 0
        }
    }
    
    func handleCrashAudio() {
        // Play tire squeal at max intensity
        if let tireNode = tireAudioNodes.first {
            tireNode.runAction(SCNAction.playAudio(tireSquealSound, waitForCompletion: false))
        }
        
        // Play brake sound
        if let brakeNode = tireAudioNodes.last {
            brakeNode.runAction(SCNAction.playAudio(brakeSound, waitForCompletion: false))
        }
    }
    
    // MARK: - AI Car Respawning
    
    func checkAndRespawnDistantAICars() {
        let playerPos = carNode.position
        let maxDistance: CGFloat = 3000.0 // Respawn if more than ~185 miles away (increased from 125 miles)
        
        for i in 0..<aiCars.count {
            let aiCar = aiCars[i]
            let distance = sqrt(pow(CGFloat(aiCar.node.position.x - playerPos.x), 2) + 
                               pow(CGFloat(aiCar.node.position.z - playerPos.z), 2))
            
            // If AI car is too far away, remove and respawn
            if distance > maxDistance {
                print("🔄 Respawning AI car #\(i+1) - was \(Int(distance)) units away")
                
                // Remove the old car
                aiCar.node.removeFromParentNode()
                
                // Create a new spawn with the same index (to keep same color)
                spawnAICar(carIndex: i)
                
                // Remove the old car from the array (spawnAICar will add new one)
                aiCars.remove(at: i)
                
                break // Only respawn one per frame to avoid issues
            }
        }
        
        // Also ensure we always have 4 AI cars
        while aiCars.count < maxAICars {
            let missingIndex = aiCars.count
            print("➕ Creating missing AI car #\(missingIndex + 1)")
            spawnAICar(carIndex: missingIndex)
        }
    }
    
    // MARK: - Car Physics Functions
    
    func updateAICarWheels(_ aiCar: inout AICar) {
        let wheelRotationSpeed = aiCar.currentSpeed * (1.0 / 60.0) * 0.1
        
        aiCar.node.enumerateChildNodes { (node, _) in
            if let name = node.name, name.contains("wheel") {
                // Rotate wheels based on speed
                node.eulerAngles.x -= CGFloat(wheelRotationSpeed)
            
                // Turn front wheels based on steering angle
                if name.contains("wheel_0") || name.contains("wheel_1") {
                    node.eulerAngles.y = CGFloat(aiCar.steeringAngle)
                }
            }
        }
    }
    
    func updateAICarSpin(_ aiCar: inout AICar) {
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Continue spinning with physics
        aiCar.spinRotation += 8.0 * deltaTime
        aiCar.node.eulerAngles.y += CGFloat(8.0 * deltaTime)
        
        // Decelerate
        aiCar.currentSpeed = max(0, aiCar.currentSpeed - 40.0 * deltaTime)
        
        // Move forward slightly while spinning (conservation of momentum)
        let moveDistance = aiCar.currentSpeed * deltaTime * 0.3
        let spinHeading = CGFloat(aiCar.node.eulerAngles.y)
        aiCar.node.position.x += CGFloat(sin(spinHeading) * moveDistance)
        aiCar.node.position.z += CGFloat(cos(spinHeading) * moveDistance)
        
        // Stop spinning after 1.5 rotations
        if aiCar.spinRotation > CGFloat.pi * 3 {
            aiCar.isSpinning = false
            aiCar.spinRotation = 0
            aiCar.currentSpeed = 0
            aiCar.steeringAngle = 0
        }
    }
    
    func updateAICarFleeing(_ aiCar: inout AICar) {
        // Flee along roads at high speed
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Find the road segment furthest from player
        guard let routePoints = interstateRoutes[aiCar.routeName],
              routePoints.count >= 2 else {
            ensureAICarOnRoad(&aiCar)
            return
        }
        
        // Drive forward on road at extreme speed
        let targetSpeed: CGFloat = 150.0 // High speed but following road
        followRoadForward(&aiCar, speed: targetSpeed)
        
        // Keep track of route for proper road following
        let currentHighway = getCurrentHighway(position: aiCar.node.position)
        if currentHighway != "" && currentHighway != aiCar.routeName {
            aiCar.routeName = currentHighway
        }
    }
    
    func updateAICarPursuit(_ aiCar: inout AICar) {
        // Pursuit along roads (used as fallback)
        let playerPos = carNode.position
        followRoadTowardTarget(&aiCar, targetPos: playerPos, speed: 85.0)
    }
} 