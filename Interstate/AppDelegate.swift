//
//  AppDelegate.swift
//  Interstate
//
//  Created by Todd Bruss on 6/19/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Disable automatic state restoration completely
        UserDefaults.standard.set(false, forKey: "NSPersistentUIShowQuietSafeQuitStatus")
        UserDefaults.standard.set(false, forKey: "NSWindowRestoreShowsToolbar")
        UserDefaults.standard.set(false, forKey: "NSWindowEnableSavedFrameStringAdditions")
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")
        
        // Disable automatic termination and resume
        NSApplication.shared.disableRelaunchOnLogin()
        
        print("🚫 Disabled automatic state restoration and frequent UserDefaults writes")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
