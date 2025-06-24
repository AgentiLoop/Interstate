//
//  GameViewController+CarPhysics.swift
//  Interstate
//
//  Car physics and movement handling
//

import SceneKit
import Foundation

extension GameViewController {
    
    // MARK: - Car Physics Update
    
    func updateCarPhysics() {
        let deltaTime: Float = 1.0 / 60.0
        
        // Update speed based on input - MORE REALISTIC FEEL
        if isAccelerating {
            carSpeed = min(carSpeed + acceleration * deltaTime, maxSpeed)
        } else if isBraking {
            carSpeed = max(carSpeed - deceleration * deltaTime, -maxSpeed * 0.3)
        } else {
            // Strong natural deceleration for realistic feel
            if carSpeed > 0 {
                carSpeed = max(carSpeed - deceleration * 0.6 * deltaTime, 0)
            } else if carSpeed < 0 {
                carSpeed = min(carSpeed + deceleration * 0.6 * deltaTime, 0)
            }
        }
        
        // Update steering based on continuous input - ONLY IF CAR IS MOVING!
        let steeringSpeed: Float = 30.0 // Reduced from 40 for less oversteering
        
        // Car must be moving to steer (minimum speed threshold)
        let canSteer = abs(carSpeed) > 1.0  // Need at least 1 m/s to steer
        
        if canSteer {
            if isTurningLeft && !isTurningRight {
                steeringAngle = max(steeringAngle - steeringSpeed * deltaTime, -maxSteeringAngle)
            } else if isTurningRight && !isTurningLeft {
                steeringAngle = min(steeringAngle + steeringSpeed * deltaTime, maxSteeringAngle)
            } else {
                // Return steering to center when not actively steering
                let returnSpeed: Float = 60.0 * deltaTime  // Faster return to match faster steering
                if steeringAngle > 0.1 {
                    steeringAngle = max(steeringAngle - returnSpeed, 0)
                } else if steeringAngle < -0.1 {
                    steeringAngle = min(steeringAngle + returnSpeed, 0)
                } else {
                    steeringAngle = 0
                }
            }
        } else {
            // If car is stopped, gradually return wheels to center
            let returnSpeed: Float = 20.0 * deltaTime  // Faster return when stopped too
            if abs(steeringAngle) > 0.1 {
                if steeringAngle > 0 {
                    steeringAngle = max(steeringAngle - returnSpeed, 0)
                } else {
                    steeringAngle = min(steeringAngle + returnSpeed, 0)
                }
            } else {
                steeringAngle = 0
            }
        }
        
        // Apply car movement - ARCADE-STYLE SUPER RESPONSIVE STEERING
        if abs(carSpeed) > 0.1 {
            
            if abs(steeringAngle) > 0.1 {
                // Proper steering physics - FIXED DIRECTION
                let steeringRadians = -steeringAngle * Float.pi / 180.0  // NEGATIVE for correct direction
                let speedFactor = min(abs(carSpeed) / 10.0, 1.0) // Steering effectiveness based on speed
                let turnRate = steeringRadians * speedFactor
                
                // Apply rotation based on forward/reverse
                let direction: Float = carSpeed >= 0 ? 1.0 : -1.0  // Reverse steering when backing up
                let angularVelocity = turnRate * direction * deltaTime * 2.0  // 2x for better response
                
                // Rotate car
                let currentY = Float(carNode.eulerAngles.y)
                let newY = currentY + angularVelocity
                carNode.eulerAngles = SCNVector3(0, newY, 0)
            }
            
            // Move car forward in the direction it's facing
            let currentHeading = Float(carNode.eulerAngles.y)
            let moveX = sin(currentHeading) * carSpeed * deltaTime
            let moveZ = cos(currentHeading) * carSpeed * deltaTime
            
            carNode.position = SCNVector3(
                carNode.position.x + CGFloat(moveX),
                1.1, // Keep car properly on ground with raised suspension
                carNode.position.z + CGFloat(moveZ)
            )
        }
        
        // ROTATE THE WHEELS BASED ON SPEED
        let wheelRotationSpeed = carSpeed * deltaTime * 0.5 // Adjust multiplier for realistic rotation
        
        // Find all wheel nodes and rotate them
        carNode.enumerateChildNodes { (node, _) in
            if let name = node.name, name.hasPrefix("wheel_") {
                // Rotate wheels around their X axis (forward/backward rotation)
                let currentRotation = node.eulerAngles.x
                node.eulerAngles.x = currentRotation + CGFloat(wheelRotationSpeed)
                
                // Front wheels also turn left/right based on steering
                if name == "wheel_0" || name == "wheel_1" { // Front wheels
                    // FIXED: Negate steering angle for correct direction
                    node.eulerAngles.y = CGFloat(-steeringAngle * Float.pi / 180.0)
                }
            }
        }
    }
}