//
//  AppDelegate.swift
//  Interstate
//
//  Created by Todd Bruss on 6/19/25.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // Keys for storing window frame
    private let windowFrameKey = "Interstate.WindowFrame"
    private let mapEditorWindowFrameKey = "Interstate.MapEditorWindowFrame"
    
    // Map Editor window reference
    private var mapEditorWindow: NSWindow?
    
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
        
        // Set up menu bar
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        let mainMenu = NSApplication.shared.mainMenu ?? NSMenu()
        
        // Add Tools menu if it doesn't exist
        var toolsMenu: NSMenu?
        for menuItem in mainMenu.items {
            if menuItem.title == "Tools" {
                toolsMenu = menuItem.submenu
                break
            }
        }
        
        if toolsMenu == nil {
            let toolsMenuItem = NSMenuItem(title: "Tools", action: nil, keyEquivalent: "")
            toolsMenu = NSMenu(title: "Tools")
            toolsMenuItem.submenu = toolsMenu
            
            // Insert before the Window menu (or at the end if Window menu doesn't exist)
            var insertIndex = mainMenu.items.count
            for (index, item) in mainMenu.items.enumerated() {
                if item.title == "Window" {
                    insertIndex = index
                    break
                }
            }
            mainMenu.insertItem(toolsMenuItem, at: insertIndex)
        }
        
        // Add Map Editor menu item
        let mapEditorMenuItem = NSMenuItem(
            title: "Open Map Editor",
            action: #selector(openMapEditor),
            keyEquivalent: "m"
        )
        mapEditorMenuItem.keyEquivalentModifierMask = [.command, .shift]
        mapEditorMenuItem.target = self
        toolsMenu?.addItem(mapEditorMenuItem)
        
        print("🔧 Added Map Editor menu item: Tools → Open Map Editor (⌘⇧M)")
    }
    
    @objc private func openMapEditor() {
        if let existingWindow = mapEditorWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            print("🗺️ Brought existing Map Editor window to front")
            return
        }
        
        // Create the SwiftUI content view
        let dataManager = DataManager()
        let contentView = ContentView().environmentObject(dataManager)
        
        // Create the hosting view
        let hostingView = NSHostingView(rootView: contentView)
        
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Interstate Map Editor"
        window.contentView = hostingView
        window.minSize = NSSize(width: 1000, height: 700)
        window.setFrameAutosaveName("MapEditorWindow")
        
        // Keep window in memory when closed (don't release)
        window.isReleasedWhenClosed = false
        
        // Restore window frame if saved
        if let frameString = UserDefaults.standard.string(forKey: mapEditorWindowFrameKey) {
            window.setFrame(NSRectFromString(frameString), display: true)
            print("🪟 Restored Map Editor window frame: \(frameString)")
        } else {
            window.center()
        }
        
        // Set up window delegate to handle closing
        window.delegate = self
        
        // Store reference
        mapEditorWindow = window
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        print("🗺️ Created and opened Map Editor window")
    }
    
    @objc internal func windowDidMove(_ notification: Notification) {
        saveWindowFrame(notification)
    }
    
    @objc internal func windowDidResize(_ notification: Notification) {
        saveWindowFrame(notification)
    }
    
    private func saveWindowFrame(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            let frameString = NSStringFromRect(window.frame)
            
            if window == mapEditorWindow {
                UserDefaults.standard.set(frameString, forKey: mapEditorWindowFrameKey)
            } else {
                UserDefaults.standard.set(frameString, forKey: windowFrameKey)
            }
            // No need to synchronize immediately - let it happen naturally
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Final save when app terminates
        if let window = NSApplication.shared.windows.first {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: windowFrameKey)
        }
        
        if let mapEditorWindow = mapEditorWindow {
            let frameString = NSStringFromRect(mapEditorWindow.frame)
            UserDefaults.standard.set(frameString, forKey: mapEditorWindowFrameKey)
        }
        
        UserDefaults.standard.synchronize()
        print("💾 Saved all window frames on termination")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == mapEditorWindow {
            // Save Map Editor window frame before closing
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: mapEditorWindowFrameKey)
            
            // Keep the window reference - don't release the window
            print("🗺️ Map Editor window closed but kept in memory")
        }
    }
}
