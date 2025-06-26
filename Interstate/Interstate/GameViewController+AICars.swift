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
        let heading: Float
        let speed: Float
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
        
        print("🎨 Creating AI car with color: R:\(color.redComponent), G:\(color.greenComponent), B:\(color.blueComponent)")
        
        let carNode = createAICarNode(color: color)
        
        // Spawn at random distance between 10-25 miles from player
        let playerPos = self.carNode.position
        let playerHeading = Float(self.carNode.eulerAngles.y)
        
        // Convert miles to game units (1 mile = 1609.34 meters, 1 meter = 0.01 game units)
        let minDistanceMiles: Float = 25.0  // Spawn between 25-75 miles
        let maxDistanceMiles: Float = 75.0
        let minDistance: Float = minDistanceMiles * 1609.34 * 0.01 // ~402 units
        let maxDistance: Float = maxDistanceMiles * 1609.34 * 0.01 // ~1207 units
        
        // Random distance between min and max
        let spawnDistance = Float.random(in: minDistance...maxDistance)
        
        // Random angle around the player (0 to 2π)
        let randomAngle = Float.random(in: 0...(2 * Float.pi))
        
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
            currentSpeed: Float.random(in: 50...70), // Start with some speed
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
            fleeStartTime: 0
        )
        
        aiCars.append(aiCar)
        scene.rootNode.addChildNode(carNode)
        
        print("🚗 Spawned AI car #\(carIndex+1) at distance: \(spawnDistance) units (\(spawnDistance / (1609.34 * 0.01)) miles)")
    }
    
    // MARK: - Helper function to find nearest road
    
    struct RoadInfo {
        let position: SCNVector3
        let heading: Float
        let routeName: String
    }
    
    func findNearestRoad(to position: SCNVector3) -> RoadInfo {
        var nearestRoad = RoadInfo(position: position, heading: 0, routeName: "")
        var minDistance = Float.infinity
        
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
                
                let segmentLengthSq = Float(segmentVec.x * segmentVec.x + segmentVec.z * segmentVec.z)
                if segmentLengthSq > 0 {
                    let dotProduct = Float(toPoint.x * segmentVec.x + toPoint.z * segmentVec.z)
                    let t = max(0, min(1, dotProduct / segmentLengthSq))
                    
                    let closestPoint = SCNVector3(
                        pos1.x + segmentVec.x * CGFloat(t),
                        0,
                        pos1.z + segmentVec.z * CGFloat(t)
                    )
                    
                    let dist = sqrt(pow(Float(position.x - closestPoint.x), 2) + 
                                   pow(Float(position.z - closestPoint.z), 2))
                    
                    if dist < minDistance {
                        minDistance = dist
                        
                        // Calculate heading of this road segment
                        let heading = atan2(Float(pos2.x - pos1.x), Float(pos2.z - pos1.z))
                        
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
                heading: Float(carNode.eulerAngles.y),
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
        let deltaTime: Float = 1.0 / 60.0
        
        // Check if car is fleeing
        if aiCar.isFleeing {
            let currentTime = CACurrentMediaTime()
            let fleeElapsed = currentTime - aiCar.fleeStartTime
            
            // Flee for 10 seconds
            if fleeElapsed > 10.0 {
                aiCar.isFleeing = false
                
                // Calculate distance reached
                let playerPos = carNode.position
                let distanceToPlayer = sqrt(pow(Float(aiCar.node.position.x - playerPos.x), 2) + 
                                           pow(Float(aiCar.node.position.z - playerPos.z), 2))
                let distanceMiles = distanceToPlayer / (1609.34 * 0.01)
                
                print("🏃 AI car stopped fleeing after 10 seconds, reached \(Int(distanceMiles)) miles away")
            } else {
                // Continue fleeing
                updateAICarFleeing(&aiCar)
                updateAICarWheels(&aiCar)
                return
            }
        }
        
        // Get player's current position and highway
        let playerPos = carNode.position
        let playerHighway = getCurrentHighway(position: playerPos)
        
        // Calculate distance to player
        let distanceToPlayer = sqrt(pow(Float(aiCar.node.position.x - playerPos.x), 2) + 
                                   pow(Float(aiCar.node.position.z - playerPos.z), 2))
        
        // If very close to player and on same road, follow their path
        if aiCar.routeName == playerHighway && distanceToPlayer < 300 && playerPath.count > 10 {
            updateAICarPathFollowing(&aiCar)
        } else {
            // Otherwise, actively drive toward the player
            updateAICarPursuit(&aiCar)
        }
        
        // Update wheels
        updateAICarWheels(&aiCar)
    }
    
    func updateAICarPursuit(_ aiCar: inout AICar) {
        let deltaTime: Float = 1.0 / 60.0
        let playerPos = carNode.position
        
        // Calculate direct vector to player
        let dx = Float(playerPos.x - aiCar.node.position.x)
        let dz = Float(playerPos.z - aiCar.node.position.z)
        let distanceToPlayer = sqrt(dx * dx + dz * dz)
        
        // Calculate desired heading directly toward player
        let desiredHeading = atan2(dx, dz)
        let currentHeading = Float(aiCar.node.eulerAngles.y)
        
        // Calculate heading difference
        var headingDiff = desiredHeading - currentHeading
        while headingDiff > Float.pi { headingDiff -= 2 * Float.pi }
        while headingDiff < -Float.pi { headingDiff += 2 * Float.pi }
        
        // REALISTIC STEERING based on speed
        let maxSteeringAngle: Float = 0.6 // Slightly higher for pursuit
        let speedFactor = max(0.1, min(1.0, 20.0 / (aiCar.currentSpeed + 1.0)))
        let steeringRate: Float = 4.0 * speedFactor // Faster steering for pursuit
        
        let desiredSteering = max(-maxSteeringAngle, min(maxSteeringAngle, headingDiff * 3.0))
        let steeringDiff = desiredSteering - aiCar.steeringAngle
        aiCar.steeringAngle += steeringDiff * min(1.0, steeringRate * deltaTime)
        
        // Apply steering
        if abs(aiCar.currentSpeed) > 0.1 {
            let turningRadius = aiCar.wheelBase / tan(abs(aiCar.steeringAngle) + 0.001)
            let angularVelocity = aiCar.currentSpeed / turningRadius
            aiCar.node.eulerAngles.y += CGFloat(angularVelocity * deltaTime * (aiCar.steeringAngle > 0 ? 1 : -1))
        }
        
        // SPEED CONTROL - go faster when far away
        let targetSpeed: Float
        if distanceToPlayer > 1000 {
            targetSpeed = 100.0 // Max speed when very far
        } else if distanceToPlayer > 500 {
            targetSpeed = 85.0
        } else if distanceToPlayer > 200 {
            targetSpeed = 75.0
        } else if distanceToPlayer > 50 {
            targetSpeed = 65.0
        } else {
            targetSpeed = max(carSpeed, 50.0) // Match player speed when close
        }
        
        // Realistic acceleration/deceleration
        let maxAcceleration: Float = 50.0 // Higher acceleration for pursuit
        let maxBraking: Float = 70.0
        
        let speedDiff = targetSpeed - aiCar.currentSpeed
        if speedDiff > 0 {
            aiCar.currentSpeed += min(speedDiff, maxAcceleration * deltaTime)
        } else {
            aiCar.currentSpeed += max(speedDiff, -maxBraking * deltaTime)
        }
        
        // Always maintain minimum speed
        if aiCar.currentSpeed < 30 {
            aiCar.currentSpeed = 30
        }
        
        // Move forward based on heading
        let moveDistance = aiCar.currentSpeed * deltaTime
        let carHeading = Float(aiCar.node.eulerAngles.y)
        
        aiCar.node.position.x += CGFloat(sin(carHeading) * moveDistance)
        aiCar.node.position.z += CGFloat(cos(carHeading) * moveDistance)
        aiCar.node.position.y = 1.1
        
        // Update route name based on current position
        let currentHighway = getCurrentHighway(position: aiCar.node.position)
        if currentHighway != "" && currentHighway != aiCar.routeName {
            aiCar.routeName = currentHighway
            print("🚗 AI car switched to highway: \(currentHighway)")
        }
    }
    
    func updateAICarPathFollowing(_ aiCar: inout AICar) {
        let deltaTime: Float = 1.0 / 60.0
        
        // Find the target point on the player's path
        let targetOffset = 30 + (aiCars.firstIndex(where: { $0.node == aiCar.node }) ?? 0) * 15
        let targetIndex = min(max(0, playerPath.count - targetOffset), playerPath.count - 1)
        
        if targetIndex >= playerPath.count {
            return
        }
        
        let targetPoint = playerPath[targetIndex]
        let currentPos = aiCar.node.position
        
        // Calculate distance and direction to target
        let dx = Float(targetPoint.position.x - currentPos.x)
        let dz = Float(targetPoint.position.z - currentPos.z)
        let distanceToTarget = sqrt(dx * dx + dz * dz)
        
        // Calculate desired heading
        let desiredHeading = atan2(dx, dz)
        let currentHeading = Float(aiCar.node.eulerAngles.y)
        
        // Calculate heading difference
        var headingDiff = desiredHeading - currentHeading
        while headingDiff > Float.pi { headingDiff -= 2 * Float.pi }
        while headingDiff < -Float.pi { headingDiff += 2 * Float.pi }
        
        // REALISTIC STEERING based on speed
        let maxSteeringAngle: Float = 0.5
        let speedFactor = max(0.1, min(1.0, 20.0 / (aiCar.currentSpeed + 1.0)))
        let steeringRate: Float = 3.0 * speedFactor
        
        let desiredSteering = max(-maxSteeringAngle, min(maxSteeringAngle, headingDiff * 2.0))
        let steeringDiff = desiredSteering - aiCar.steeringAngle
        aiCar.steeringAngle += steeringDiff * min(1.0, steeringRate * deltaTime)
        
        // Apply Ackermann steering geometry
        if abs(aiCar.currentSpeed) > 0.1 {
            let turningRadius = aiCar.wheelBase / tan(abs(aiCar.steeringAngle) + 0.001)
            let angularVelocity = aiCar.currentSpeed / turningRadius
            aiCar.node.eulerAngles.y += CGFloat(angularVelocity * deltaTime * (aiCar.steeringAngle > 0 ? 1 : -1))
        }
        
        // SPEED CONTROL
        let targetSpeed: Float
        if distanceToTarget < 20 {
            targetSpeed = max(30, targetPoint.speed * 0.8)
        } else if distanceToTarget > 100 {
            targetSpeed = min(120, targetPoint.speed * 1.3)
        } else {
            targetSpeed = targetPoint.speed
        }
        
        // Realistic acceleration/deceleration
        let maxAcceleration: Float = 40.0
        let maxBraking: Float = 60.0
        
        let speedDiff = targetSpeed - aiCar.currentSpeed
        if speedDiff > 0 {
            aiCar.currentSpeed += min(speedDiff, maxAcceleration * deltaTime)
        } else {
            aiCar.currentSpeed += max(speedDiff, -maxBraking * deltaTime)
        }
        
        // Ensure minimum speed
        if distanceToTarget > 10 && aiCar.currentSpeed < 20 {
            aiCar.currentSpeed = 20
        }
        
        // Move forward based on heading and speed
        let moveDistance = aiCar.currentSpeed * deltaTime
        let carHeading = Float(aiCar.node.eulerAngles.y)
        
        aiCar.node.position.x += CGFloat(sin(carHeading) * moveDistance)
        aiCar.node.position.z += CGFloat(cos(carHeading) * moveDistance)
        aiCar.node.position.y = 1.1
    }
    
    func findClosestRoadPoint(for aiCar: inout AICar, on routeName: String) {
        guard let routePoints = interstateRoutes[routeName],
              routePoints.count >= 2 else {
            return
        }
        
        var closestSegment = 0
        var closestT: Float = 0
        var minDist = Float.infinity
        
        for i in 0..<routePoints.count-1 {
            let point1 = routePoints[i]
            let point2 = routePoints[i + 1]
            
            let pos1 = gpsToSceneKit(latitude: point1.0, longitude: point1.1)
            let pos2 = gpsToSceneKit(latitude: point2.0, longitude: point2.1)
            
            // Find closest point on segment
            let segmentVec = SCNVector3(pos2.x - pos1.x, 0, pos2.z - pos1.z)
            let toPoint = SCNVector3(aiCar.node.position.x - pos1.x, 0, aiCar.node.position.z - pos1.z)
            
            let segmentLengthSq = Float(segmentVec.x * segmentVec.x + segmentVec.z * segmentVec.z)
            if segmentLengthSq > 0 {
                let dotProduct = Float(toPoint.x * segmentVec.x + toPoint.z * segmentVec.z)
                let tRaw = dotProduct / segmentLengthSq
                let t = max(0, min(1, tRaw))
                let closestPoint = SCNVector3(pos1.x + segmentVec.x * CGFloat(t), 0, pos1.z + segmentVec.z * CGFloat(t))
                let dist = sqrt(pow(Float(aiCar.node.position.x - closestPoint.x), 2) + pow(Float(aiCar.node.position.z - closestPoint.z), 2))
                
                if dist < minDist {
                    minDist = dist
                    closestSegment = i
                    closestT = t
                }
            }
        }
        
        aiCar.routePointIndex = closestSegment
        aiCar.positionOnSegment = closestT
    }
    
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
        let deltaTime: Float = 1.0 / 60.0
        
        // Continue spinning with physics
        aiCar.spinRotation += 8.0 * deltaTime
        aiCar.node.eulerAngles.y += CGFloat(8.0 * deltaTime)
        
        // Decelerate
        aiCar.currentSpeed = max(0, aiCar.currentSpeed - 40.0 * deltaTime)
        
        // Move forward slightly while spinning (conservation of momentum)
        let moveDistance = aiCar.currentSpeed * deltaTime * 0.3
        let spinHeading = Float(aiCar.node.eulerAngles.y)
        aiCar.node.position.x += CGFloat(sin(spinHeading) * moveDistance)
        aiCar.node.position.z += CGFloat(cos(spinHeading) * moveDistance)
        
        // Stop spinning after 1.5 rotations
        if aiCar.spinRotation > Float.pi * 3 {
            aiCar.isSpinning = false
            aiCar.spinRotation = 0
            aiCar.currentSpeed = 0
            aiCar.steeringAngle = 0
        }
    }
    
    func updateAICarFleeing(_ aiCar: inout AICar) {
        let deltaTime: Float = 1.0 / 60.0
        let playerPos = carNode.position
        
        // Calculate vector AWAY from player
        let dx = Float(aiCar.node.position.x - playerPos.x)
        let dz = Float(aiCar.node.position.z - playerPos.z)
        let distanceToPlayer = sqrt(dx * dx + dz * dz)
        
        // Normalize the flee direction
        let fleeX = dx / distanceToPlayer
        let fleeZ = dz / distanceToPlayer
        
        // Calculate desired heading (away from player)
        let desiredHeading = atan2(fleeX, fleeZ)
        let currentHeading = Float(aiCar.node.eulerAngles.y)
        
        // Calculate heading difference
        var headingDiff = desiredHeading - currentHeading
        while headingDiff > Float.pi { headingDiff -= 2 * Float.pi }
        while headingDiff < -Float.pi { headingDiff += 2 * Float.pi }
        
        // PANIC STEERING - turn faster when fleeing
        let maxSteeringAngle: Float = 0.8 // Higher for panic
        let steeringRate: Float = 5.0 // Very fast steering
        
        let desiredSteering = max(-maxSteeringAngle, min(maxSteeringAngle, headingDiff * 4.0))
        let steeringDiff = desiredSteering - aiCar.steeringAngle
        aiCar.steeringAngle += steeringDiff * min(1.0, steeringRate * deltaTime)
        
        // Apply steering
        if abs(aiCar.currentSpeed) > 0.1 {
            let turningRadius = aiCar.wheelBase / tan(abs(aiCar.steeringAngle) + 0.001)
            let angularVelocity = aiCar.currentSpeed / turningRadius
            aiCar.node.eulerAngles.y += CGFloat(angularVelocity * deltaTime * (aiCar.steeringAngle > 0 ? 1 : -1))
        }
        
        // EXTREME FLEE SPEED - to reach 100-150 miles in 10 seconds!
        let targetSpeed: Float = 200.0 // Extremely high speed (~450 mph) to cover distance quickly
        
        // Very quick acceleration when fleeing
        let maxAcceleration: Float = 100.0 // Ultra-fast acceleration
        let speedDiff = targetSpeed - aiCar.currentSpeed
        if speedDiff > 0 {
            aiCar.currentSpeed += min(speedDiff, maxAcceleration * deltaTime)
        }
        
        // Move forward based on heading
        let moveDistance = aiCar.currentSpeed * deltaTime
        let carHeading = Float(aiCar.node.eulerAngles.y)
        
        aiCar.node.position.x += CGFloat(sin(carHeading) * moveDistance)
        aiCar.node.position.z += CGFloat(cos(carHeading) * moveDistance)
        aiCar.node.position.y = 1.1
        
        // Update route name based on current position
        let currentHighway = getCurrentHighway(position: aiCar.node.position)
        if currentHighway != "" && currentHighway != aiCar.routeName {
            aiCar.routeName = currentHighway
        }
    }
    
    // MARK: - Collision Detection
    
    func checkAICarCollision(_ aiCar: AICar) {
        let playerPos = carNode.position
        let aiPos = aiCar.node.position
        
        // Calculate distance
        let distance = sqrt(pow(Float(playerPos.x - aiPos.x), 2) + 
                          pow(Float(playerPos.z - aiPos.z), 2))
        
        // Check for collision (slightly larger collision distance for realism)
        if distance < collisionDistance * 1.2 {
            // Calculate collision angle
            let collisionAngle = atan2(Float(aiPos.x - playerPos.x), Float(aiPos.z - playerPos.z))
            let playerHeading = Float(carNode.eulerAngles.y)
            
            // Determine spin direction based on collision angle
            var angleDiff = collisionAngle - playerHeading
            while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
            while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }
            
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
        let deltaTime: Float = 1.0 / 60.0
        
        // Spin the car with physics
        playerSpinAngle += playerSpinVelocity * deltaTime
        carNode.eulerAngles.y += CGFloat(playerSpinVelocity * deltaTime)
        
        // Reduce car speed dramatically but keep some momentum
        let brakingForce: Float = 50.0
        carSpeed = max(0, carSpeed - brakingForce * deltaTime)
        
        // Move slightly while spinning (conservation of momentum)
        let moveDistance = carSpeed * deltaTime * 0.3
        let spinHeading = Float(carNode.eulerAngles.y)
        carNode.position.x += CGFloat(sin(spinHeading) * moveDistance)
        carNode.position.z += CGFloat(cos(spinHeading) * moveDistance)
        
        // Reduce spin velocity (friction)
        let friction: Float = 5.0
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
        let maxDistance: Float = 3000.0 // Respawn if more than ~185 miles away (increased from 125 miles)
        
        for i in 0..<aiCars.count {
            let aiCar = aiCars[i]
            let distance = sqrt(pow(Float(aiCar.node.position.x - playerPos.x), 2) + 
                               pow(Float(aiCar.node.position.z - playerPos.z), 2))
            
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
} 