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
        //autoreleasepool {
            updateCarPhysics()
            updateCameraPosition() // Update camera independently
            updateDynamicRoads() // Load/unload roads based on player position
            updateDynamicCheckpoints() // Load/unload checkpoint signs based on proximity
            checkForCheckpointCollision() // Check for checkpoint hits
            updateCarAudio() // Update realistic car audio system
            updateHUD()
            updateRadarMap()
            
            // REMOVED: Aggressive cleanup was removing roads the player is on
            // performAggressiveMemoryCleanup()
            
            // REMOVED: Memory pressure check was too aggressive
            // checkMemoryPressure()
        //}
    }
    
    // MARK: - Memory Management
    
    func performAggressiveMemoryCleanup() {
        let now = Date()
        if now.timeIntervalSince(lastMemoryCleanup) < memoryCleanupInterval {
            return
        }
        
        autoreleasepool {
            let playerPosition = carNode.position
            
            // 1. Only clean up routes that are VERY far away (different states)
            let veryDistantCleanupDistance: Float = 50000.0 // 50km - only clean up distant states
            var routesToCleanup: [String] = []
            
            for (routeName, _) in routeSmoothPoints {
                if let gpsCoordinates = routeGPSData[routeName] {
                    var isFarAway = true
                    
                    // Check fewer sample points for performance
                    let sampleIndices = [0, gpsCoordinates.count / 2, gpsCoordinates.count - 1]
                    
                    for index in sampleIndices {
                        if index < gpsCoordinates.count {
                            let (lat, lon) = gpsCoordinates[index]
                            let routePoint = gpsToSceneKit(latitude: lat, longitude: lon)
                            let distance = sqrt(pow(playerPosition.x - routePoint.x, 2) + 
                                              pow(playerPosition.z - routePoint.z, 2))
                            
                            if Float(distance) <= veryDistantCleanupDistance {
                                isFarAway = false
                                break
                            }
                        }
                    }
                    
                    if isFarAway {
                        routesToCleanup.append(routeName)
                    }
                }
            }
            
            // Clean up only very distant routes
            for routeName in routesToCleanup {
                routeSmoothPoints.removeValue(forKey: routeName)
                allRoadPoints.removeValue(forKey: routeName)
                print("🧹 Gentle cleanup: Removed very distant route \(routeName)")
            }
            
            // 2. Only clean up nodes that are EXTREMELY far (10km+)
            var nodesToRemove: [SCNNode] = []
            scene.rootNode.enumerateChildNodes { (node, _) in
                if let name = node.name {
                    // Only remove nodes that are extremely far from player
                    let nodeDistance = sqrt(pow(playerPosition.x - node.position.x, 2) + 
                                          pow(playerPosition.z - node.position.z, 2))
                    
                    if Float(nodeDistance) > 10000.0 { // 10km - much more conservative
                        if name.contains("road") || name.contains("dash") || name.contains("edgeLine") {
                            // Don't remove checkpoint-related nodes
                            if !name.contains("checkpoint") && !name.contains("banner") && !name.contains("pole") {
                                nodesToRemove.append(node)
                            }
                        }
                    }
                }
            }
            
            for node in nodesToRemove {
                node.removeFromParentNode()
            }
            
            if !nodesToRemove.isEmpty {
                print("🧹 Gentle cleanup: Removed \(nodesToRemove.count) extremely distant nodes")
            }
            
            // 3. Only hint garbage collection if we actually cleaned something significant
            if routesToCleanup.count > 2 || nodesToRemove.count > 50 {
                DispatchQueue.main.async {
                    autoreleasepool {
                        // Empty pool to encourage cleanup
                    }
                }
            }
        }
        
        lastMemoryCleanup = now
    }
    
    // MARK: - Memory Pressure Detection
    
    func checkMemoryPressure() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryUsageMB = memoryInfo.resident_size / (1024 * 1024)
            
            // If memory usage is over 800MB, trigger emergency cleanup
            if memoryUsageMB > 800 {
                print("⚠️ High memory usage detected: \(memoryUsageMB)MB - triggering emergency cleanup")
                performEmergencyMemoryCleanup()
            }
        }
    }
    
    func performEmergencyMemoryCleanup() {
        autoreleasepool {
            let playerPosition = carNode.position
            
            // 1. Emergency: Only remove roads beyond 2km (keep roads player is on!)
            let emergencyRoadDistance: Float = 2000.0 // 2km - much more conservative
            
            // 2. Unload distant roads but keep nearby ones
            for (routeName, nodes) in loadedRoadNodes {
                var nodesToRemove: [SCNNode] = []
                
                for node in nodes {
                    let distance = sqrt(pow(playerPosition.x - node.position.x, 2) + 
                                      pow(playerPosition.z - node.position.z, 2))
                    
                    if Float(distance) > emergencyRoadDistance {
                        nodesToRemove.append(node)
                    }
                }
                
                for node in nodesToRemove {
                    node.removeFromParentNode()
                    if let index = loadedRoadNodes[routeName]?.firstIndex(of: node) {
                        loadedRoadNodes[routeName]?.remove(at: index)
                    }
                }
            }
            
            // 3. Only clear routes that are very far away (20km+)
            var routesToClear: [String] = []
            for (routeName, _) in routeSmoothPoints {
                if let gpsCoordinates = routeGPSData[routeName] {
                    var isVeryFar = true
                    
                    // Check multiple points to see if ANY part of the route is close
                    let checkIndices = [0, gpsCoordinates.count / 4, gpsCoordinates.count / 2, 
                                       (3 * gpsCoordinates.count) / 4, gpsCoordinates.count - 1]
                    
                    for index in checkIndices {
                        if index < gpsCoordinates.count {
                            let (lat, lon) = gpsCoordinates[index]
                            let routePoint = gpsToSceneKit(latitude: lat, longitude: lon)
                            let distance = sqrt(pow(playerPosition.x - routePoint.x, 2) + 
                                              pow(playerPosition.z - routePoint.z, 2))
                            
                            if Float(distance) <= 20000.0 { // 20km emergency threshold
                                isVeryFar = false
                                break
                            }
                        }
                    }
                    
                    if isVeryFar {
                        routesToClear.append(routeName)
                    }
                }
            }
            
            for routeName in routesToClear {
                routeSmoothPoints.removeValue(forKey: routeName)
                allRoadPoints.removeValue(forKey: routeName)
                loadedRouteSegments[routeName] = Set<Int>()
            }
            
            // 4. Unload distant checkpoints (but keep closer ones for gameplay)
            var checkpointsToUnload: [String] = []
            for (cityName, checkpoint) in loadedCheckpoints {
                let distance = sqrt(pow(playerPosition.x - checkpoint.position.x, 2) + 
                                  pow(playerPosition.z - checkpoint.position.z, 2))
                
                if Float(distance) > 5000.0 { // 5km emergency threshold - much more generous for checkpoints
                    checkpointsToUnload.append(cityName)
                }
            }
            
            for cityName in checkpointsToUnload {
                if let checkpoint = loadedCheckpoints[cityName] {
                    checkpoint.removeFromParentNode()
                    loadedCheckpoints.removeValue(forKey: cityName)
                }
            }
            
            print("🚨 Emergency cleanup completed: Cleared \(routesToClear.count) routes, \(checkpointsToUnload.count) checkpoints")
        }
    }
}
