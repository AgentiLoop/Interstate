//
//  GameViewController+Camera.swift
//  Interstate
//
//  Camera system and following behavior
//

import SceneKit
import Foundation

extension GameViewController {
    
    // MARK: - Camera Setup
    
    func setupCamera() {
        // PROPER THIRD-PERSON DRIVING CAMERA - NOT ATTACHED TO CAR
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 75 // Wider FOV to see more road ahead
        cameraNode.camera?.zFar = 1000.0 // See further into the distance
        
        // Get car's starting position (use saved position)
        let carStartPos = gpsToSceneKit(latitude: lastSavedPosition.0, longitude: lastSavedPosition.1)
        
        // Position camera behind and above the car's starting position
        cameraNode.position = SCNVector3(carStartPos.x, CGFloat(cameraHeight) + 0.5, carStartPos.z - CGFloat(cameraDistance))
        
        // Point camera ahead of the car to show more road
        let initialLookAhead: CGFloat = 10.0
        cameraNode.look(at: SCNVector3(carStartPos.x, 0.5, carStartPos.z + initialLookAhead), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        
        // Add camera directly to scene, NOT as child of car
        scene.rootNode.addChildNode(cameraNode)
        
        // Set initial camera target
        updateCameraPosition()
    }
    
    // MARK: - Camera Update
    
    func updateCameraPosition() {
        let dampingFactor: CGFloat = 0.15
        
        // Get car's heading
        let carHeading = carNode.eulerAngles.y
        
        // Calculate camera offset based on car direction (behind the car)
        let cameraOffsetX = sin(carHeading + CGFloat.pi) * cameraDistance
        let cameraOffsetZ = cos(carHeading + CGFloat.pi) * cameraDistance
        
        targetCameraPosition = SCNVector3(
            carNode.position.x + cameraOffsetX,
            carNode.position.y + cameraHeight,
            carNode.position.z + cameraOffsetZ
        )
        
        // Camera should look ahead of the car to show more road
        let lookAheadDistance: CGFloat = 10.0  // Standard look-ahead for road visibility
        let lookAheadX = sin(carHeading) * lookAheadDistance
        let lookAheadZ = cos(carHeading) * lookAheadDistance
        
        targetCameraLookAt = SCNVector3(
            carNode.position.x + lookAheadX,
            carNode.position.y, // Look at road level ahead
            carNode.position.z + lookAheadZ
        )
        
        // Smoothly move camera to target position
        let currentPos = cameraNode.position
        let deltaX = (targetCameraPosition.x - currentPos.x) * CGFloat(cameraFollowSpeed) * CGFloat(1.0/60.0)
        let deltaY = (targetCameraPosition.y - currentPos.y) * CGFloat(cameraFollowSpeed) * CGFloat(1.0/60.0)
        let deltaZ = (targetCameraPosition.z - currentPos.z) * CGFloat(cameraFollowSpeed) * CGFloat(1.0/60.0)
        
        cameraNode.position = SCNVector3(
            currentPos.x + deltaX,
            currentPos.y + deltaY,
            currentPos.z + deltaZ
        )
        
        // Point camera at the car using look(at:) for proper third-person view
        cameraNode.look(at: targetCameraLookAt, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }
}