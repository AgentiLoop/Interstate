//
//  GameViewController+Audio.swift
//  Interstate
//
//  Car audio system implementation
//

import SceneKit
import AVFoundation
import Foundation

extension GameViewController {
    
    // MARK: - Car Audio System Setup
    
    func setupCarAudio() {
        print("🔊 Setting up realistic car audio system...")
        
        // Initialize audio sources
        initializeAudioSources()
        
        // Create audio nodes for positional audio
        setupAudioNodes()
        
        // Start the engine
        startEngine()
        
        // Test the audio system
        testAudioSystem()
        
        print("✅ Car audio system initialized successfully!")
    }
    
    private func initializeAudioSources() {
        // Load engine sounds
        engineStartSound = createAudioSource(named: "engine_start.mp3")
        engineIdleSound = createAudioSource(named: "engine_idle.mp3", shouldLoop: true)
        engineRevSound = createAudioSource(named: "engine_rev.mp3", shouldLoop: true)
        
        // Load gear shifting sounds (6-speed transmission)
        for gear in 1...6 {
            let shiftSound = createAudioSource(named: "engine_shifting_\(gear).mp3")
            engineShiftingSounds.append(shiftSound)
        }
        
        // Load tire and brake sounds
        tireSquealSound = createAudioSource(named: "tire_squeal.mp3", shouldLoop: true)
        brakeSound = createAudioSource(named: "brake_sound.mp3")
        
        print("🎵 Loaded \(engineShiftingSounds.count + 5) car audio files")
    }
    
    private func createAudioSource(named fileName: String, shouldLoop: Bool = false) -> SCNAudioSource {
        guard let audioSource = SCNAudioSource(fileNamed: "\(fileName)") else {
            print("⚠️ Failed to load audio file: \(fileName)")
            print("📁 Make sure the file exists in Interstate/Sounds/ directory")
            print("📄 Expected path: Sounds/\(fileName)")
            
            // Create a silent audio source as fallback
            let fallbackSource = SCNAudioSource()
            fallbackSource.loops = shouldLoop
            fallbackSource.isPositional = true
            fallbackSource.volume = 0.0 // Silent fallback
            return fallbackSource
        }
        
        print("✅ Successfully loaded audio file: \(fileName)")
        audioSource.loops = shouldLoop
        audioSource.isPositional = true
        audioSource.volume = 1.0
        audioSource.load()
        
        return audioSource
    }
    
    private func setupAudioNodes() {
        // Engine audio node (front of car)
        engineAudioNode = SCNNode()
        engineAudioNode.position = SCNVector3(0, 0.5, 1.5) // Front of car
        carNode.addChildNode(engineAudioNode)
        
        // Exhaust audio node (rear of car)
        exhaustAudioNode = SCNNode()
        exhaustAudioNode.position = SCNVector3(0, 0.2, -2.0) // Rear of car
        carNode.addChildNode(exhaustAudioNode)
        
        // Tire audio nodes (one for each wheel)
        let tirePositions = [
            SCNVector3(-0.8, 0.1, 1.2),  // Front left
            SCNVector3(0.8, 0.1, 1.2),   // Front right
            SCNVector3(-0.8, 0.1, -1.2), // Rear left
            SCNVector3(0.8, 0.1, -1.2)   // Rear right
        ]
        
        for position in tirePositions {
            let tireNode = SCNNode()
            tireNode.position = position
            carNode.addChildNode(tireNode)
            tireAudioNodes.append(tireNode)
        }
        
        print("🎯 Created \(tireAudioNodes.count + 2) positional audio nodes")
    }
    
    // MARK: - Engine Audio Control
    
    private func startEngine() {
        guard !isEngineRunning else { return }
        
        print("🚗 Starting engine...")
        
        // Play engine start sound
        engineAudioNode.runAction(SCNAction.playAudio(engineStartSound, waitForCompletion: false))
        
        // Start idle sound after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.startEngineIdle()
            self.isEngineRunning = true
        }
    }
    
    private func startEngineIdle() {
        engineIdlePlayer = SCNAudioPlayer(source: engineIdleSound)
        engineAudioNode.addAudioPlayer(engineIdlePlayer!)
    }
    
    private func updateEngineSound() {
        guard isEngineRunning else { return }
        
        let speedKmh = abs(carSpeed) * 3.6 // Convert m/s to km/h
        
        // Calculate RPM based on speed and current gear
        calculateEngineRPM(speedKmh: speedKmh)
        
        // Update engine sound volumes and pitch
        updateEngineSoundParameters()
        
        // Check for gear shifts
        checkForGearShift(speedKmh: speedKmh)
        
        // Handle acceleration/deceleration sounds
        handleAccelerationSounds()
    }
    
    private func calculateEngineRPM(speedKmh: Float) -> Float {
        // Realistic gear ratios for a 6-speed transmission
        let gearRatios: [Float] = [0, 3.8, 2.1, 1.4, 1.0, 0.8, 0.6] // Index 0 unused
        let finalDriveRatio: Float = 3.9
        let wheelCircumference: Float = 2.0 // meters
        
        if currentGear >= 1 && currentGear <= 6 {
            let wheelRPM = (speedKmh / 3.6) * 60 / wheelCircumference
            let rpm = wheelRPM * gearRatios[currentGear] * finalDriveRatio
            
            // Clamp RPM to realistic range
            let calculatedRPM = max(800, min(maxRPM, rpm))
            engineRPM = calculatedRPM // Update the instance variable
            return calculatedRPM
        }
        
        engineRPM = 800 // Update instance variable to idle
        return 800 // Idle RPM
    }
    
    private func updateEngineSoundParameters() {
        // Calculate engine load factor (0.0 to 1.0)
        let loadFactor = (engineRPM - 800.0) / (maxRPM - 800.0)
        
        // Update rev sound volume (increases as RPM increases)
        if engineRevPlayer == nil && loadFactor > 0.3 {
            startEngineRevSound()
        }
        
        // Stop rev sound if RPM is low
        if loadFactor < 0.2 && engineRevPlayer != nil {
            stopEngineRevSound()
        }
    }
    
    private func startEngineRevSound() {
        engineRevPlayer = SCNAudioPlayer(source: engineRevSound)
        exhaustAudioNode.addAudioPlayer(engineRevPlayer!)
    }
    
    private func stopEngineRevSound() {
        exhaustAudioNode.removeAudioPlayer(engineRevPlayer!)
        engineRevPlayer = nil
    }
    
    // MARK: - Gear Shifting System
    
    private func checkForGearShift(speedKmh: Float) {
        let speedDifference = abs(speedKmh - lastSpeedForGearShift)
        
        // Only check for shifts if speed has changed significantly
        guard speedDifference > 2.0 else { return }
        
        let newGear = calculateOptimalGear(speedKmh: speedKmh)
        
        if newGear != currentGear {
            performGearShift(from: currentGear, to: newGear)
            currentGear = newGear
        }
        
        lastSpeedForGearShift = speedKmh
    }
    
    private func calculateOptimalGear(speedKmh: Float) -> Int {
        // Realistic shift points for a performance car
        switch speedKmh {
        case 0..<15: return 1
        case 15..<35: return 2
        case 35..<60: return 3
        case 60..<90: return 4
        case 90..<130: return 5
        default: return 6
        }
    }
    
    private func performGearShift(from oldGear: Int, to newGear: Int) {
        print("⚙️ Shifting from gear \(oldGear) to gear \(newGear)")
        
        // Play appropriate shifting sound
        let shiftSoundIndex = min(newGear - 1, engineShiftingSounds.count - 1)
        if shiftSoundIndex >= 0 && shiftSoundIndex < engineShiftingSounds.count {
            let shiftSound = engineShiftingSounds[shiftSoundIndex]
            engineAudioNode.runAction(SCNAction.playAudio(shiftSound, waitForCompletion: false))
        }
        
        // Brief RPM drop during shift (realistic)
        let tempRPM = engineRPM
        engineRPM = max(800, engineRPM * 0.7)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.engineRPM = tempRPM
        }
    }
    
    // MARK: - Brake and Tire Audio
    
    private func handleBrakingAudio() {
        if isBraking && carSpeed > 5.0 {
            // Play brake sound
            if tireAudioNodes.count >= 2 {
                tireAudioNodes[0].runAction(SCNAction.playAudio(brakeSound, waitForCompletion: false))
            }
            
            // Add tire squeal if braking hard
            let brakingForce = abs(carSpeed) / maxSpeed
            if brakingForce > 0.3 && tireSquealPlayer == nil {
                startTireSqueal(intensity: brakingForce)
            }
        } else {
            stopTireSqueal()
        }
    }
    
    private func handleAccelerationSounds() {
        // Handle tire squeal during rapid acceleration
        if isAccelerating && carSpeed < 20.0 && carSpeed > 2.0 {
            let accelerationForce = acceleration / 20.0 // Normalize
            if accelerationForce > 0.6 && tireSquealPlayer == nil {
                startTireSqueal(intensity: accelerationForce * 0.7)
            }
        }
        
        // Handle cornering tire squeal
        let corneringForce = abs(steeringAngle) / maxSteeringAngle
        if corneringForce > 0.7 && carSpeed > 30.0 && tireSquealPlayer == nil {
            startTireSqueal(intensity: corneringForce * 0.8)
        }
        
        // Stop tire squeal if conditions are no longer met
        if !isAccelerating && !isBraking && abs(steeringAngle) < 0.3 {
            stopTireSqueal()
        }
    }
    
    private func startTireSqueal(intensity: Float) {
        guard tireSquealPlayer == nil else { return }
        
        tireSquealPlayer = SCNAudioPlayer(source: tireSquealSound)
        
        // Play from rear tires
        if tireAudioNodes.count >= 4 {
            tireAudioNodes[2].addAudioPlayer(tireSquealPlayer!) // Rear left
            tireAudioNodes[3].addAudioPlayer(tireSquealPlayer!) // Rear right
        }
        
        // Volume is controlled by the SCNAudioSource, not the player
        
        print("🛞 Tire squeal started (intensity: \(String(format: "%.2f", intensity)))")
    }
    
    private func stopTireSqueal() {
        guard let player = tireSquealPlayer else { return }
        
        // Remove from all tire nodes
        for tireNode in tireAudioNodes {
            tireNode.removeAudioPlayer(player)
        }
        
        tireSquealPlayer = nil
        print("🛞 Tire squeal stopped")
    }
    
    // MARK: - Audio Update Method
    
    func updateCarAudio() {
        let currentTime = CACurrentMediaTime()
        
        // Only update audio once per second
        if currentTime - lastAudioUpdateTime < audioUpdateInterval {
            return
        }
        
        lastAudioUpdateTime = currentTime
        
        // Call existing methods
        updateEngineSound()
        handleBrakingAudio()
    }
    
    // MARK: - Debug Audio Test Method
    
    private func testAudioSystem() {
        print("🔊 Testing audio system...")
        
        // Test if we can play a system sound
        NSSound.beep()
        
        // Test if our audio nodes are properly set up
        if engineAudioNode != nil {
            print("✅ Engine audio node exists")
        } else {
            print("❌ Engine audio node is nil")
        }
        
        if exhaustAudioNode != nil {
            print("✅ Exhaust audio node exists")
        } else {
            print("❌ Exhaust audio node is nil")
        }
        
        print("🔊 Tire audio nodes count: \(tireAudioNodes.count)")
        
        // Test if audio sources loaded
        print("🎵 Engine start sound loaded: \(engineStartSound != nil)")
        print("🎵 Engine idle sound loaded: \(engineIdleSound != nil)")
        print("🎵 Engine rev sound loaded: \(engineRevSound != nil)")
        print("🎵 Tire squeal sound loaded: \(tireSquealSound != nil)")
        print("🎵 Brake sound loaded: \(brakeSound != nil)")
        print("🎵 Gear shift sounds loaded: \(engineShiftingSounds.count)")
    }
}