//
//  GameViewController+CarModel.swift
//  Interstate
//
//  Car model creation and wheel setup
//

import SceneKit
import AppKit

extension GameViewController {
    
    // MARK: - Car Model Creation
    
    func createCarNode() -> SCNNode {
        // Main car container
        let carContainer = SCNNode()
        carContainer.name = "carContainer"
        
        // Car body - main chassis
        let bodyGeometry = SCNBox(width: 4.0, height: 1.5, length: 8.0, chamferRadius: 0.3)
        let bodyMaterial = SCNMaterial()
        bodyMaterial.diffuse.contents = NSColor.systemBlue
        bodyMaterial.metalness.contents = 0.7
        bodyMaterial.roughness.contents = 0.3
        bodyMaterial.lightingModel = .physicallyBased
        bodyGeometry.materials = [bodyMaterial]
        
        let bodyNode = SCNNode(geometry: bodyGeometry)
        bodyNode.position = SCNVector3(0, 1.8, 0)
        bodyNode.name = "body"
        carContainer.addChildNode(bodyNode)
        
        // Car roof/cabin
        let roofGeometry = SCNBox(width: 3.5, height: 1.8, length: 4.5, chamferRadius: 0.5)
        roofGeometry.materials = [bodyMaterial]
        let roofNode = SCNNode(geometry: roofGeometry)
        roofNode.position = SCNVector3(0, 3.0, -0.8)
        carContainer.addChildNode(roofNode)
        
        // Glass material for all windows - light blue tint
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = NSColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 0.3)
        glassMaterial.metalness.contents = 0.0
        glassMaterial.roughness.contents = 0.0
        glassMaterial.transparency = 0.7
        glassMaterial.lightingModel = .physicallyBased
        glassMaterial.isDoubleSided = true
        
        // Front Windshield
        let windshieldGeometry = SCNBox(width: 3.3, height: 1.4, length: 0.1, chamferRadius: 0)
        windshieldGeometry.materials = [glassMaterial]
        
        let windshieldNode = SCNNode(geometry: windshieldGeometry)
        windshieldNode.position = SCNVector3(0, 3.1, 1.5)
        windshieldNode.eulerAngles.x = -0.3
        carContainer.addChildNode(windshieldNode)
        
        // Rear Window
        let rearWindowGeometry = SCNBox(width: 3.2, height: 1.2, length: 0.1, chamferRadius: 0)
        rearWindowGeometry.materials = [glassMaterial]
        
        let rearWindowNode = SCNNode(geometry: rearWindowGeometry)
        rearWindowNode.position = SCNVector3(0, 3.1, -3.2)
        rearWindowNode.eulerAngles.x = 0.4  // Angled back slightly
        carContainer.addChildNode(rearWindowNode)
        
        // Side Windows - Driver's side
        let sideWindowGeometry = SCNBox(width: 0.1, height: 1.2, length: 1.8, chamferRadius: 0)
        sideWindowGeometry.materials = [glassMaterial]
        
        // Front driver window
        let driverFrontWindow = SCNNode(geometry: sideWindowGeometry)
        driverFrontWindow.position = SCNVector3(-1.75, 3.0, 0.2)
        carContainer.addChildNode(driverFrontWindow)
        
        // Rear driver window
        let driverRearWindow = SCNNode(geometry: sideWindowGeometry)
        driverRearWindow.position = SCNVector3(-1.75, 3.0, -1.8)
        carContainer.addChildNode(driverRearWindow)
        
        // Side Windows - Passenger side
        // Front passenger window
        let passengerFrontWindow = SCNNode(geometry: sideWindowGeometry)
        passengerFrontWindow.position = SCNVector3(1.75, 3.0, 0.2)
        carContainer.addChildNode(passengerFrontWindow)
        
        // Rear passenger window
        let passengerRearWindow = SCNNode(geometry: sideWindowGeometry)
        passengerRearWindow.position = SCNVector3(1.75, 3.0, -1.8)
        carContainer.addChildNode(passengerRearWindow)
        
        // Small triangular windows near mirrors (quarter windows)
        let quarterWindowGeometry = SCNBox(width: 0.1, height: 0.8, length: 0.6, chamferRadius: 0)
        quarterWindowGeometry.materials = [glassMaterial]
        
        let driverQuarterWindow = SCNNode(geometry: quarterWindowGeometry)
        driverQuarterWindow.position = SCNVector3(-1.75, 2.9, 1.3)
        driverQuarterWindow.eulerAngles.z = -0.2  // Slight angle
        carContainer.addChildNode(driverQuarterWindow)
        
        let passengerQuarterWindow = SCNNode(geometry: quarterWindowGeometry)
        passengerQuarterWindow.position = SCNVector3(1.75, 2.9, 1.3)
        passengerQuarterWindow.eulerAngles.z = 0.2  // Slight angle
        carContainer.addChildNode(passengerQuarterWindow)
        
        // Side Mirrors
        let mirrorMaterial = SCNMaterial()
        mirrorMaterial.diffuse.contents = NSColor(white: 0.1, alpha: 1.0)
        mirrorMaterial.metalness.contents = 0.8
        mirrorMaterial.roughness.contents = 0.2
        
        // Driver side mirror
        let driverMirrorBase = SCNBox(width: 0.3, height: 0.2, length: 0.4, chamferRadius: 0.05)
        driverMirrorBase.materials = [mirrorMaterial]
        let driverMirrorNode = SCNNode(geometry: driverMirrorBase)
        driverMirrorNode.position = SCNVector3(-2.0, 2.6, 1.2)
        carContainer.addChildNode(driverMirrorNode)
        
        // Passenger side mirror
        let passengerMirrorNode = driverMirrorNode.clone()
        passengerMirrorNode.position = SCNVector3(2.0, 2.6, 1.2)
        carContainer.addChildNode(passengerMirrorNode)
        
        // Mirror glass (reflective surface)
        let mirrorGlassMaterial = SCNMaterial()
        mirrorGlassMaterial.diffuse.contents = NSColor(white: 0.9, alpha: 1.0)
        mirrorGlassMaterial.metalness.contents = 1.0
        mirrorGlassMaterial.roughness.contents = 0.05
        
        let mirrorGlass = SCNBox(width: 0.25, height: 0.15, length: 0.02, chamferRadius: 0)
        mirrorGlass.materials = [mirrorGlassMaterial]
        
        let driverMirrorGlass = SCNNode(geometry: mirrorGlass)
        driverMirrorGlass.position = SCNVector3(-0.15, 0, 0)
        driverMirrorNode.addChildNode(driverMirrorGlass)
        
        let passengerMirrorGlass = SCNNode(geometry: mirrorGlass)
        passengerMirrorGlass.position = SCNVector3(0.15, 0, 0)
        passengerMirrorNode.addChildNode(passengerMirrorGlass)
        
        // Create wheels with proper rotation setup
        let wheelNodes = createWheels()
        for (index, wheelNode) in wheelNodes.enumerated() {
            wheelNode.name = "wheel_\(index)"
            carContainer.addChildNode(wheelNode)
        }
        
        // Headlights
        let headlightMaterial = SCNMaterial()
        headlightMaterial.diffuse.contents = NSColor.white
        headlightMaterial.emission.contents = NSColor(white: 1.0, alpha: 0.8)
        headlightMaterial.lightingModel = .constant
        
        for x in [-1.2, 1.2] {
            let headlightGeometry = SCNSphere(radius: 0.3)
            headlightGeometry.materials = [headlightMaterial]
            let headlightNode = SCNNode(geometry: headlightGeometry)
            headlightNode.position = SCNVector3(x, 1.6, 4.1)
            
            // Add actual light
            let light = SCNLight()
            light.type = .spot
            light.color = NSColor.white
            light.intensity = 500
            light.spotInnerAngle = 30
            light.spotOuterAngle = 60
            light.attenuationStartDistance = 0
            light.attenuationEndDistance = 30
            headlightNode.light = light
            
            // Point the light forward
            headlightNode.look(at: SCNVector3(x, 0, 10), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
            
            carContainer.addChildNode(headlightNode)
        }
        
        // Tail lights
        let tailLightMaterial = SCNMaterial()
        tailLightMaterial.diffuse.contents = NSColor.red
        tailLightMaterial.emission.contents = NSColor(red: 0.8, green: 0, blue: 0, alpha: 1.0)
        tailLightMaterial.lightingModel = .constant
        
        for x in [-1.5, 1.5] {
            let tailLightGeometry = SCNBox(width: 0.6, height: 0.3, length: 0.1, chamferRadius: 0.1)
            tailLightGeometry.materials = [tailLightMaterial]
            let tailLightNode = SCNNode(geometry: tailLightGeometry)
            tailLightNode.position = SCNVector3(x, 1.6, -4.1)
            carContainer.addChildNode(tailLightNode)
        }
        
        // Add details - door lines
        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = NSColor.black
        
        for z in [-0.5, -2.5] {
            let doorLine = SCNBox(width: 0.05, height: 1.2, length: 1.5, chamferRadius: 0)
            doorLine.materials = [lineMaterial]
            let doorNode = SCNNode(geometry: doorLine)
            doorNode.position = SCNVector3(2.01, 2.4, z)
            carContainer.addChildNode(doorNode)
            
            let doorNode2 = doorNode.clone()
            doorNode2.position.x = -2.01
            carContainer.addChildNode(doorNode2)
        }
        
        // Bumpers
        let bumperMaterial = SCNMaterial()
        bumperMaterial.diffuse.contents = NSColor(white: 0.2, alpha: 1.0)
        bumperMaterial.metalness.contents = 0.8
        bumperMaterial.roughness.contents = 0.2
        
        let frontBumper = SCNBox(width: 4.2, height: 0.4, length: 0.3, chamferRadius: 0.1)
        frontBumper.materials = [bumperMaterial]
        let frontBumperNode = SCNNode(geometry: frontBumper)
        frontBumperNode.position = SCNVector3(0, 1.4, 4.15)
        carContainer.addChildNode(frontBumperNode)
        
        let rearBumper = frontBumper.copy() as! SCNBox
        rearBumper.materials = [bumperMaterial]
        let rearBumperNode = SCNNode(geometry: rearBumper)
        rearBumperNode.position = SCNVector3(0, 1.4, -4.15)
        carContainer.addChildNode(rearBumperNode)
        
        return carContainer
    }
    
    // MARK: - Wheel Creation
    
    func createWheels() -> [SCNNode] {
        var wheels: [SCNNode] = []
        
        let wheelPositions = [
            SCNVector3(-1.8, 1.2, 2.5),   // Front left
            SCNVector3(1.8, 1.2, 2.5),    // Front right
            SCNVector3(-1.8, 1.2, -2.5),  // Rear left
            SCNVector3(1.8, 1.2, -2.5)    // Rear right
        ]
        
        for position in wheelPositions {
            let wheelContainer = SCNNode()
            wheelContainer.position = position
            
            // Tire - dark gray rubber
            let tireGeometry = SCNTorus(ringRadius: 0.6, pipeRadius: 0.5)
            let tireMaterial = SCNMaterial()
            tireMaterial.diffuse.contents = NSColor(white: 0.1, alpha: 1.0)
            tireMaterial.roughness.contents = 0.9
            tireMaterial.metalness.contents = 0.0
            tireGeometry.materials = [tireMaterial]
            
            let tireNode = SCNNode(geometry: tireGeometry)
            tireNode.eulerAngles = SCNVector3(0, 0, CGFloat.pi/2)
            wheelContainer.addChildNode(tireNode)
            
            // Create tread material
            let treadMaterial = SCNMaterial()
            treadMaterial.diffuse.contents = NSColor(white: 0.05, alpha: 1.0)
            treadMaterial.roughness.contents = 0.95
            treadMaterial.metalness.contents = 0.0
            
            // Rim - metallic silver with spokes
            let rimGeometry = SCNCylinder(radius: 0.45, height: 0.25)
            let rimMaterial = SCNMaterial()
            rimMaterial.diffuse.contents = NSColor(white: 0.8, alpha: 1.0)
            rimMaterial.metalness.contents = 0.9
            rimMaterial.roughness.contents = 0.1
            rimGeometry.materials = [rimMaterial]
            
            let rimNode = SCNNode(geometry: rimGeometry)
            rimNode.eulerAngles = SCNVector3(CGFloat.pi/2, 0, 0)
            wheelContainer.addChildNode(rimNode)
            
            // Spokes
            let spokeMaterial = SCNMaterial()
            spokeMaterial.diffuse.contents = NSColor(white: 0.7, alpha: 1.0)
            spokeMaterial.metalness.contents = 0.8
            
            for angle in stride(from: 0, to: 360, by: 45) {
                let spokeGeometry = SCNBox(width: 0.08, height: 0.8, length: 0.15, chamferRadius: 0)
                spokeGeometry.materials = [spokeMaterial]
                let spokeNode = SCNNode(geometry: spokeGeometry)
                
                let radians = CGFloat(angle) * CGFloat.pi / 180
                spokeNode.position = SCNVector3(0, 0, 0)
                spokeNode.eulerAngles = SCNVector3(CGFloat.pi/2, 0, radians)
                wheelContainer.addChildNode(spokeNode)
            }
            
            // Center hub
            let hubGeometry = SCNCylinder(radius: 0.15, height: 0.3)
            hubGeometry.materials = [rimMaterial]
            let hubNode = SCNNode(geometry: hubGeometry)
            hubNode.eulerAngles = SCNVector3(CGFloat.pi/2, 0, 0)
            wheelContainer.addChildNode(hubNode)
            
            wheels.append(wheelContainer)
        }
        
        return wheels
    }
}