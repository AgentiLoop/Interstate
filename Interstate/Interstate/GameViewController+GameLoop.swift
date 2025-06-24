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
        // URGENT DEBUG: Check if game loop is running
        NSLog("🚨 DEBUG: gameLoop ENTRY")
        
        autoreleasepool {
            updateCarPhysics()
            updateCameraPosition() // Update camera independently
            
            NSLog("🚨 DEBUG: About to call updateDynamicRoads")
            updateDynamicRoads() // This now includes memory-managed route updates
            NSLog("🚨 DEBUG: Called updateDynamicRoads, no crash")
            updateDynamicCheckpoints() // Load/unload checkpoint signs based on proximity
            checkForCheckpointCollision() // Check for checkpoint hits
            updateCarAudio() // Update realistic car audio system
            updateHUD()
            updateRadarMap()
            
            // Periodic memory status logging (every 15 seconds and only if routes are loaded)
            let currentTime = Int(Date().timeIntervalSince1970)
            if currentTime % 15 == 0 && loadedRouteData.count > 0 {
                // Memory status now logged automatically by the background system
            }
        }
    }
    
    // MARK: - Legacy Memory Management (Replaced by Memory-Managed Routes)
    
    // Note: The old memory management functions have been replaced by the new
    // memory-managed route loading system in GameViewController+MemoryManagedRoutes.swift
    // This provides better control over the 256MB memory budget and ensures
    // routes currently being driven on are never unloaded.
}
