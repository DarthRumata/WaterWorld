//
//  PredationManager.swift
//  WaterWorld Shared
//
//  Extracted predation planning and execution logic from GameScene.
//

import Foundation
import CoreGraphics

// Events that the environment can apply to organisms during a tick
enum OrganismEvent {
    case damage(id: UUID, amount: Double)
    case kill(id: UUID, cause: CauseOfDeath)
}

@MainActor
final class PredationManager {
    private var intensity: PredatorsIntensity
    private var predationSystem: PredationSystem
    private var nightAttackSchedule: [TimeInterval] = []
    private var nightElapsed: TimeInterval = 0

    init(intensity: PredatorsIntensity) {
        self.intensity = intensity
        self.predationSystem = PredationManager.makeSystem(for: intensity)
    }

    func updateIntensity(_ newIntensity: PredatorsIntensity) {
        self.intensity = newIntensity
        self.predationSystem = PredationManager.makeSystem(for: newIntensity)
        // Clear any existing schedule so a new plan can be created with the new intensity
        self.nightAttackSchedule.removeAll()
    }

    func advanceDayProgress(dayProgress: Double, tickDuration: TimeInterval) {
        let isNight = dayProgress >= 0.5
        if isNight {
            nightElapsed += tickDuration
        } else {
            nightElapsed = 0
            nightAttackSchedule.removeAll()
        }
    }

    func ensurePlanIfNight(dayProgress: Double) {
        guard intensity != .off else { return }
        let isNight = dayProgress >= 0.5
        guard isNight, nightAttackSchedule.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let schedule = await predationSystem.planNightAttacks()
            await MainActor.run {
                self.nightAttackSchedule = schedule
            }
        }
    }

    func processDueAttacks(pairs: [(id: UUID, depth: CGFloat)]) async -> [OrganismEvent] {
        guard intensity != .off else { return [] }
        guard !nightAttackSchedule.isEmpty else { return [] }

        // Determine which attacks are due
        let dueTimes = nightAttackSchedule.filter { $0 <= nightElapsed }
        guard !dueTimes.isEmpty else { return [] }

        // Remove executed times
        nightAttackSchedule.removeAll { $0 <= nightElapsed }

        // Eligible targets (near the surface)
        let cutoffDepth = GlobalConstants.maxDepth * GlobalConstants.predationDodgeMaxDepthFraction
        let eligibleSnapshot = pairs.filter { Double($0.depth) <= cutoffDepth }
        guard !eligibleSnapshot.isEmpty else { return [] }

        var events: [OrganismEvent] = []
        for _ in dueTimes {
            if let target = await predationSystem.chooseTarget(from: eligibleSnapshot) {
                let depth = eligibleSnapshot.first(where: { $0.id == target })?.depth ?? 0
                let depthFraction = max(0.0, min(1.0, Double(depth) / GlobalConstants.maxDepth))
                let capped = min(depthFraction, GlobalConstants.predationDodgeMaxDepthFraction)
                let t = GlobalConstants.predationDodgeMaxDepthFraction == 0 ? 0 : (capped / GlobalConstants.predationDodgeMaxDepthFraction)
                let dodgeChance = GlobalConstants.predationDodgeBaseChance + (GlobalConstants.predationDodgeMaxChance - GlobalConstants.predationDodgeBaseChance) * t
                let dodged = Double.random(in: 0..<1) < dodgeChance
                if dodged {
                    events.append(.damage(id: target, amount: GlobalConstants.predationDamageOnDodge))
                } else {
                    events.append(.kill(id: target, cause: .predation))
                }
            }
        }
        return events
    }

    private static func makeSystem(for intensity: PredatorsIntensity) -> PredationSystem {
        PredationSystem(config: .init(
            killBudgetFactor: intensity.factor,
            nightDuration: GlobalConstants.dayDuration / 2,
            riskFromDepth: { depth in
                // Higher risk near surface: normalizedDepth in [0, 1], risk = (1 - normalized)^2
                let normalized = max(0, min(1, depth / GlobalConstants.maxDepth))
                return pow(Double(1 - normalized), 2.0)
            }
        ))
    }
}
