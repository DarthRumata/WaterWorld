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
    static let predationDodgeEnergyRequired: Double = 100.0                      // Minimum energy needed to execute a dodge
    nonisolated(unsafe) static var predationDodgeCost: Double = 90.0             // Min dodge cost (at boundary depth 0.3)
    static let predationDodgeCostMax: Double = 180.0                             // Max dodge cost (at surface, depth 0)
    static let predationDodgeSafetyBuffer: Double = 10.0                         // Extra energy required above dodge cost to attempt a dodge

    static func dodgeCost(atDepth depth: Double) -> Double {
        let cutoff = maxDepth * predationDodgeMaxDepthFraction
        let t = (cutoff - min(depth, cutoff)) / cutoff   // 1.0 at surface, 0.0 at boundary
        return predationDodgeCost + t * (predationDodgeCostMax - predationDodgeCost)
    }

// Movement — fraction of container height per tick, so 25 ticks always = full traversal
    static let movementPaceFraction: CGFloat = 1.0 / 25

    // Auto-save
    static let autoSaveLifespanThreshold: Int = 100

    // Reward shaping
    static let rewardTickSurvivalBonus: Double = 0.02
    /// Energy needed to survive one full night waiting (half day, moderate movement).
    /// Reward is neutral at this level, negative below, positive above.
    static var rewardCriticalEnergyThreshold: Double {
        let nightTicks = dayDuration * 0.5 / gameTickDuration   // ticks per night at speed=1
        return nightTicks * (idleEnergyLoss + movementEnergyLoss * 0.5) // ~60
    }
    static var rewardEnergyDeltaScale: Double        { predationDodgeCost }
    static var rewardEnergyLossPenaltyScale: Double  { predationDodgeCost * 3 }
}
