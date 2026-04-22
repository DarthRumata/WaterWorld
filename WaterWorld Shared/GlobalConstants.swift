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
    static let predationDodgeMaxDepthFraction: Double = 0.30 // Predators only reach top 30% of depth
    static let predationDodgeChance: Double = 0.5            // Probability of getting a dodge roll vs instant death
    nonisolated(unsafe) static var predationDodgeEnergyRequired: Double = 100.0  // Minimum energy needed to execute a dodge
    nonisolated(unsafe) static var predationDodgeCost: Double = 90.0             // Energy spent on a successful dodge
    // Alias used by reward shaping — computed so it tracks predationDodgeEnergyRequired
    static var predationDeathThreshold: Double { predationDodgeEnergyRequired }

    // Movement
    static let movementPace: CGFloat = 824 / 25

    // Auto-save
    static let autoSaveLifespanThreshold: Int = 100

    // Reward shaping — computed so they stay in sync when predation params change at runtime
    static let rewardTickSurvivalBonus: Double = 0.02
    static var rewardCriticalEnergyThreshold: Double { predationDeathThreshold }
    static var rewardWarningEnergyThreshold: Double  { predationDeathThreshold + predationDodgeCost }
    static var rewardEnergyDeltaScale: Double        { predationDodgeCost }
    static var rewardEnergyLossPenaltyScale: Double  { predationDodgeCost * 3 }
    static var rewardWarningPenaltyScale: Double     { predationDodgeCost * 10 }
}
