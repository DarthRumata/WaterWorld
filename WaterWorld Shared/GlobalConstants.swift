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
}
