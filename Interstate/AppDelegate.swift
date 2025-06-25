//
//  AppDelegate.swift
//  Interstate
//
//  Created by Todd Bruss on 6/19/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // Keys for storing window frame
    private let windowFrameKey = "Interstate.WindowFrame"
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Disable automatic state restoration completely
        UserDefaults.standard.set(false, forKey: "NSPersistentUIShowQuietSafeQuitStatus")
        UserDefaults.standard.set(false, forKey: "NSWindowRestoreShowsToolbar")
        UserDefaults.standard.set(false, forKey: "NSWindowEnableSavedFrameStringAdditions")
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")
        
        // Disable automatic termination and resume
        NSApplication.shared.disableRelaunchOnLogin()
        
        print("🚫 Disabled automatic state restoration and frequent UserDefaults writes")
        
        // Set up main window with minimum size and restore position
        if let window = NSApplication.shared.windows.first {
            // Set minimum window size to 800x600
            window.minSize = NSSize(width: 800, height: 600)
            
            // Restore window frame if saved
            if let frameString = UserDefaults.standard.string(forKey: windowFrameKey) {
                window.setFrame(NSRectFromString(frameString), display: true)
                print("🪟 Restored window frame: \(frameString)")
            } else {
                // Center window on first launch
                window.center()
            }
            
            // Listen for window frame changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidMove(_:)),
                name: NSWindow.didMoveNotification,
                object: window
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
            
            print("✅ Window minimum size set to 800x600")
        }
    }
    
    @objc private func windowDidMove(_ notification: Notification) {
        saveWindowFrame(notification)
    }
    
    @objc private func windowDidResize(_ notification: Notification) {
        saveWindowFrame(notification)
    }
    
    private func saveWindowFrame(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: windowFrameKey)
            // No need to synchronize immediately - let it happen naturally
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Final save when app terminates
        if let window = NSApplication.shared.windows.first {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: windowFrameKey)
            UserDefaults.standard.synchronize()
            print("💾 Saved window frame on termination: \(frameString)")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
