//
//  GameViewController+GameLoop.swift
//  Interstate
//
//  Main game loop and memory management
//

import SceneKit
import Foundation
import Darwin

extension GameViewController {
    
    // MARK: - Game Loop
    
    @objc func gameLoop() {
        autoreleasepool {
            updateCarPhysics()
            updateCameraPosition() // Update camera independently
            updateRoadMarkingOpacity() // Update road line opacity based on camera distance
            updateDynamicRoads() // This now includes memory-managed route updates
            updateDynamicCheckpoints() // Load/unload checkpoint signs based on proximity
            checkForCheckpointCollision() // Check for checkpoint hits
            updateCarAudio() // Update realistic car audio system
            updateHUD()
            updateRadarMap()
            
            // Clean up intersection overlaps every 1 second (60 frames at 60fps)
            if frameCount % 60 == 0 {
                cleanupIntersectionOverlaps(playerPosition: carNode.position)
            }
            
            frameCount += 1
            
            // Periodic memory status logging (every 15 seconds and only if routes are loaded)
//            let currentTime = Int(Date().timeIntervalSince1970)
//            if currentTime % 15 == 0 && loadedRouteData.count > 0 {
//                // Memory status now logged automatically by the background system
//            }
        }
    }
    
    // MARK: - Real-Time Road Marking Opacity Update
    
    func updateRoadMarkingOpacity() {
        // Only update every 3 frames for performance (20fps update rate)
        if frameCount % 3 != 0 { return }
        
        guard let camera = cameraNode else { return }
        
        let cameraPosition = camera.presentation.position
        let maxDistance: CGFloat = 1200.0  // Distance where opacity reaches minimum
        let minOpacity: CGFloat = 0.2      // Minimum opacity for distant markings
        let maxOpacity: CGFloat = 1.0      // Full opacity for nearby markings
        
        // Find all road marking nodes in the scene
        scene.rootNode.enumerateChildNodes { (node, _) in
            // Check if this is a road marking node (has geometry and materials)
            guard let geometry = node.geometry,
                  geometry.materials.count > 0,
                  let material = geometry.materials.first else { return }
            
            // Only update nodes that look like road markings (small boxes close to ground)
            if let box = geometry as? SCNBox,
               box.height < 0.1 && box.width < 20.0 && node.position.y < 2.0 {
                
                // Calculate distance from camera to this road marking
                let distance = sqrt(pow(node.position.x - cameraPosition.x, 2) +
                                  pow(node.position.z - cameraPosition.z, 2))
                
                // Calculate opacity based on distance
                let normalizedDistance = min(distance / maxDistance, 1.0)
                let opacity = maxOpacity - (normalizedDistance * (maxOpacity - minOpacity))
                
                // Ensure nearby markings are always full opacity
                let finalOpacity = distance < 100.0 ? 1.0 : opacity
                
                // Update material opacity if it has changed significantly
                let currentOpacity = material.diffuse.contents as? NSColor
                if currentOpacity == nil || abs(currentOpacity!.alphaComponent - finalOpacity) > 0.05 {
                    if let color = material.diffuse.contents as? NSColor {
                        material.diffuse.contents = color.withAlphaComponent(finalOpacity)
                        material.emission.contents = color.withAlphaComponent(finalOpacity * 0.3)
                    }
                }
            }
        }
    }
    
    // MARK: - Legacy Memory Management (Replaced by Memory-Managed Routes)
    
    // Note: The old memory management functions have been replaced by the new
    // memory-managed route loading system in GameViewController+MemoryManagedRoutes.swift
    // This provides better control over the 256MB memory budget and ensures
    // routes currently being driven on are never unloaded.
}
