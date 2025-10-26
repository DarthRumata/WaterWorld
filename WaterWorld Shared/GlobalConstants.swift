//
//  GlobalConstants.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Foundation

enum GlobalConstants {
    static let maxLightLevel: Double = 10
    // Total duration of one day cycle in seconds
    static let dayDuration: TimeInterval = 24.0
    static let initialPopulation = 100
    static let maxDepth: Double = 100
    static let gameTickDuration: TimeInterval = 0.25
    
    // Energy
    static let maxEnergy: Double = 200
    static let idleEnergyLoss: Double = 0.5
    static let movementEnergyLoss: Double = 1.5
    
    // Predation
    // Dodge chance grows linearly from base at the surface to max at a depth fraction cutoff
    static let predationDodgeBaseChance: Double = 0.10     // 10% at surface
    static let predationDodgeMaxChance: Double = 0.75      // 65% at cutoff depth
    static let predationDodgeMaxDepthFraction: Double = 0.30 // Cutoff at 30% of total depth
    static let predationDamageOnDodge: Double = 40.0
    
    // Movement
    static let movementPace: CGFloat = 824 / 25
}

