//
//  GameViewController+SceneSetup.swift
//  Interstate
//
//  Scene initialization and setup
//

import SceneKit
import AppKit

extension GameViewController {
    
    // MARK: - Scene Setup
    
    func setupScene() {
        scene = SCNScene()
        
        // Add some lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.light!.color = NSColor.white
        lightNode.position = SCNVector3(x: 0, y: 50, z: 0)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = NSColor(white: 0.4, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Create a large ground plane with PROPER GRASS COLOR
        let groundGeometry = SCNPlane(width: 50000, height: 50000) // Even larger for horizon
        groundGeometry.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.6, blue: 0.1, alpha: 1.0) // Vibrant grass green
        groundGeometry.firstMaterial?.roughness.contents = 1.0
        groundGeometry.firstMaterial?.metalness.contents = 0.0
        
        // Add texture pattern for grass-like appearance
        groundGeometry.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(100, 100, 1)
        groundGeometry.firstMaterial?.diffuse.wrapS = .repeat
        groundGeometry.firstMaterial?.diffuse.wrapT = .repeat
        
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.eulerAngles = SCNVector3(-Float.pi/2, 0, 0) // Rotate to be horizontal
        groundNode.position = SCNVector3(0, -0.5, 0) // Below road level
        groundNode.name = "ground"
        scene.rootNode.addChildNode(groundNode)
    }
    
    // MARK: - Car Setup
    
    func setupCar() {
        // Use the new createCarNode function to get our car model
        carNode = createCarNode()
        
        // Load last saved position or default to Los Angeles
        loadLastPosition()
        let startPosition = gpsToSceneKit(latitude: lastSavedPosition.0, longitude: lastSavedPosition.1)
        carNode.position = SCNVector3(startPosition.x, 1.1, startPosition.z)
        scene.rootNode.addChildNode(carNode)
        
        print("🚗 Car positioned at saved location: \(lastSavedPosition)")
        
        // Initialize game timing and scoring
        gameStartTime = Date()
        lastCheckpointTime = 0
        loadHighScore()
        
        // Setup car audio system
        setupCarAudio()
        
        // Setup app termination listener to save position only when exiting
        setupAppTerminationListener()
    }
}