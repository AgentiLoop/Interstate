//
//  GameViewController+InputHandler.swift
//  Interstate
//
//  Keyboard input handling
//

import SceneKit
import AppKit

extension GameViewController {
    
    // MARK: - Input Setup
    
    func setupControls() {
        // Improved key event handling to prevent system beeps
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            return self?.handleKeyEvent(event) == true ? nil : event
        }
    }
    
    // MARK: - Key Event Handling
    
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let isKeyDown = event.type == .keyDown
        
        switch keyCode {
        case 13: // S key - accelerate (GAS) - SWAPPED
            isAccelerating = isKeyDown
            return true
        case 1: // W key - brake/reverse (BRAKE) - SWAPPED
            isBraking = isKeyDown
            return true
        case 2: // A key - turn left
            isTurningRight = isKeyDown   // SWAPPED - A now turns RIGHT
            return true
        case 0: // D key - turn right
            isTurningLeft = isKeyDown   // SWAPPED - D now turns LEFT
            return true
        default:
            return false
        }
    }
}