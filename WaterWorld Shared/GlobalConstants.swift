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
    static let predationDodgeEnergyRequired: Double = 100.0  // Minimum energy needed to execute a dodge
    static let predationDodgeCost: Double = 90.0             // Energy spent on a successful dodge
    // Alias used by reward shaping
    static let predationDeathThreshold: Double = predationDodgeEnergyRequired

    // Movement
    static let movementPace: CGFloat = 824 / 25

    // Reward shaping (derived from predation constants)
    static let rewardTickSurvivalBonus: Double = 0.02
    // Below this — die on the next hit
    static let rewardCriticalEnergyThreshold: Double = predationDeathThreshold
    // Below this — survive one dodge but would die on the next hit without recovery
    static let rewardWarningEnergyThreshold: Double  = predationDeathThreshold + predationDodgeCost
    // Normaliser for energy delta signal: one full dodge cost = ±0.5
    static let rewardEnergyDeltaScale: Double        = predationDodgeCost
    // Loss penalty scale: 3× weaker than gain so movement cost isn't over-penalised
    static let rewardEnergyLossPenaltyScale: Double  = predationDodgeCost * 3
    // Scale for warning zone penalty: max penalty = dodgeCost / scale = 0.1
    static let rewardWarningPenaltyScale: Double     = predationDodgeCost * 10
}

