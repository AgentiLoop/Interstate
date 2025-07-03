import SwiftUI

@main
struct InterstateMapEditorApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Interstate Data...") {
                    dataManager.loadData()
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Button("Save Interstate Data") {
                    dataManager.saveData()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!dataManager.hasUnsavedChanges)
            }
            
            CommandMenu("Edit") {
                Button("Remove All Dirt Roads") {
                    dataManager.removeAllDirtRoads()
                }
                
                Button("Find Dead Ends") {
                    dataManager.findDeadEnds()
                }
                
                Button("Auto-Connect Nearby Routes") {
                    dataManager.autoConnectRoutes()
                }
            }
        }
    }
} 