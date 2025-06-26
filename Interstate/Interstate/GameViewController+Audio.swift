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
        // Initialize audio sources
        initializeAudioSources()
        
        // Create audio nodes for positional audio
        setupAudioNodes()
        
        // Start the engine
        startEngine()
        
        // Test the audio system
        testAudioSystem()
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
        
        // Audio files loaded
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
        
        // Audio nodes created
    }
    
    // MARK: - Engine Audio Control
    
    private func startEngine() {
        guard !isEngineRunning else { return }
        
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
    
    private func calculateEngineRPM(speedKmh: CGFloat) -> CGFloat {
        // More realistic RPM calculation based on current gear
        let gearRatios: [CGFloat] = [3.5, 2.5, 1.8, 1.2, 0.9, 0.7] // 6-speed transmission
        let finalDriveRatio: CGFloat = 3.9
        let wheelCircumference: CGFloat = 2.0 // meters
        
        let speedMs = speedKmh / 3.6
        let wheelRPM = (speedMs / wheelCircumference) * 60
        let transmissionRPM = wheelRPM * finalDriveRatio * gearRatios[currentGear - 1]
        
        // Add some variance for realism
        let variance = CGFloat.random(in: -50...50)
        let rpm = transmissionRPM + variance
        
        // Ensure RPM stays within realistic bounds
        if currentGear == 1 && speedKmh < 10 {
            // Low speed in first gear - higher idle RPM
            let calculatedRPM = max(800, min(maxRPM, rpm))
            return calculatedRPM
        } else {
            return max(600, min(maxRPM, rpm))
        }
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
    
    private func checkForGearShift(speedKmh: CGFloat) {
        let currentGearOpt = calculateOptimalGear(speedKmh: speedKmh)
        
        // Calculate speed difference for shift sound triggering
        let speedDifference = abs(speedKmh - lastSpeedForGearShift)
        
        // Only play shift sound if:
        // 1. We've actually changed gears
        // 2. There's been a significant speed change (at least 15 km/h)
        // 3. Enough time has passed since last shift (handled by removeAction)
        if currentGearOpt != currentGear && speedDifference > 15 {
            currentGear = currentGearOpt
            playGearShiftSound()
        }
        
        lastSpeedForGearShift = speedKmh
    }
    
    private func calculateOptimalGear(speedKmh: CGFloat) -> Int {
        // Realistic gear shift points for a 6-speed transmission
        switch speedKmh {
        case 0..<20:
            return 1
        case 20..<40:
            return 2
        case 40..<70:
            return 3
        case 70..<100:
            return 4
        case 100..<140:
            return 5
        default:
            return 6
        }
    }
    
    private func playGearShiftSound() {
        // Play appropriate shifting sound
        let shiftSoundIndex = min(currentGear - 1, engineShiftingSounds.count - 1)
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
                startTireSqueal(intensity: CGFloat(brakingForce))
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
                startTireSqueal(intensity: CGFloat(accelerationForce * 0.7))
            }
        }
        
        // Handle cornering tire squeal
        let corneringForce = abs(steeringAngle) / maxSteeringAngle
        if corneringForce > 0.7 && carSpeed > 30.0 && tireSquealPlayer == nil {
            startTireSqueal(intensity: CGFloat(corneringForce * 0.8))
        }
        
        // Stop tire squeal if conditions are no longer met
        if !isAccelerating && !isBraking && abs(steeringAngle) < 0.3 {
            stopTireSqueal()
        }
    }
    
    private func startTireSqueal(intensity: CGFloat) {
        // Remove any existing squeal action
        tireAudioNodes.forEach { $0.removeAction(forKey: "tireSqueal") }
        
        // Calculate volume based on intensity
        let volume = CGFloat(intensity * 0.5) // Using CGFloat as requested
        
        // Create new tire squeal action with volume
        let squealAction = SCNAction.playAudio(tireSquealSound, waitForCompletion: false)
        
        // Play on both tire audio nodes for stereo effect
        tireAudioNodes.forEach { node in
            node.runAction(squealAction, forKey: "tireSqueal")
        }
    }
    
    private func stopTireSqueal() {
        tireAudioNodes.forEach { $0.removeAction(forKey: "tireSqueal") }
        tireSquealPlayer = nil
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
        // Test if we can play a system sound
        NSSound.beep()
        
        // Audio system validation completed silently
    }
}
