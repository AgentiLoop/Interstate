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
        // Check if Map Editor window is currently focused
        if isMapEditorWindowActive() {
            // Reset input states when Map Editor is focused to prevent stuck inputs
            resetInputStates()
            // Don't capture WASD keys when Map Editor is focused
            return false
        }
        
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
    
    // MARK: - Helper Functions
    
    private func isMapEditorWindowActive() -> Bool {
        // Check if any text input is currently being edited (first responder)
        if let keyWindow = NSApplication.shared.keyWindow,
           let firstResponder = keyWindow.firstResponder {
            
            let responderClass = String(describing: type(of: firstResponder))
            
            // Check for various text input controls
            if firstResponder is NSTextView || 
               firstResponder is NSTextField ||
               responderClass.contains("Text") ||
               responderClass.contains("Field") ||
               responderClass.contains("Input") ||
               responderClass.contains("Editor") ||
               responderClass.contains("SwiftUI") {
                return true
            }
        }
        
        // Also check if the Map Editor window is the key window
        guard let keyWindow = NSApplication.shared.keyWindow else { return false }
        
        return keyWindow.title == "Interstate Map Editor"
    }
    
    private func resetInputStates() {
        // Reset all input flags to prevent stuck inputs when switching windows
        isAccelerating = false
        isBraking = false
        isTurningLeft = false
        isTurningRight = false
    }
}