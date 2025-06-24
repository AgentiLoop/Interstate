//
//  GameViewController+HighScore.swift
//  Interstate
//
//  High score management
//

import Foundation

extension GameViewController {
    
    // MARK: - High Score Management
    
    func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: "highScore")
        print("📊 Loaded high score: \(highScore)")
    }
    
    func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: "highScore")
        print("💾 Saved new high score: \(highScore)")
    }
    
    func calculateScore(population: Int) -> Int {
        // Score based on city population
        switch population {
        case 0..<100000:        return 10   // Small cities
        case 100000..<500000:   return 25   // Medium cities  
        case 500000..<1000000:  return 50   // Large cities
        case 1000000..<3000000: return 100  // Major cities
        default:                return 200  // Mega cities (NYC, LA, etc.)
        }
    }
}