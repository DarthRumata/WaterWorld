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

    func ensurePlanIfNight(dayProgress: Double, populationSize: Int) {
        guard intensity != .off else { return }
        let isNight = dayProgress >= 0.5
        guard isNight, nightAttackSchedule.isEmpty else { return }
        Task { [weak self, populationSize] in
            guard let self else { return }
            let schedule = await predationSystem.planNightAttacks(populationSize: populationSize)
            await MainActor.run {
                self.nightAttackSchedule = schedule
            }
        }
    }

    func processDueAttacks(pairs: [(id: UUID, depth: CGFloat, energy: Double)]) async -> [OrganismEvent] {
        guard intensity != .off else { return [] }
        guard !nightAttackSchedule.isEmpty else { return [] }

        let dueTimes = nightAttackSchedule.filter { $0 <= nightElapsed }
        guard !dueTimes.isEmpty else { return [] }
        nightAttackSchedule.removeAll { $0 <= nightElapsed }

        // Only organisms near the surface can be targeted
        let cutoffDepth = GlobalConstants.maxDepth * GlobalConstants.predationDodgeMaxDepthFraction
        let eligible = pairs.filter { Double($0.depth) <= cutoffDepth }
        guard !eligible.isEmpty else { return [] }

        var events: [OrganismEvent] = []
        for _ in dueTimes {
            if let targetID = await predationSystem.chooseTarget(from: eligible.map { ($0.id, $0.depth) }) {
                let targetEnergy = eligible.first(where: { $0.id == targetID })?.energy ?? 0
                let canDodge = Double.random(in: 0...1) < GlobalConstants.predationDodgeChance
                if canDodge && targetEnergy >= GlobalConstants.predationDodgeEnergyRequired {
                    events.append(.damage(id: targetID, amount: GlobalConstants.predationDodgeCost))
                } else {
                    events.append(.kill(id: targetID, cause: .predation))
                }
            }
        }
        return events
    }

    private static func makeSystem(for intensity: PredatorsIntensity) -> PredationSystem {
        PredationSystem(config: .init(
            populationFraction: intensity.populationFraction,
            minimumAttacksPerNight: intensity.minimumAttacksPerNight,
            nightDuration: GlobalConstants.dayDuration / 2,
            riskFromDepth: { depth in
                // Higher risk near surface: normalizedDepth in [0, 1], risk = (1 - normalized)^2
                let normalized = max(0, min(1, depth / GlobalConstants.maxDepth))
                return pow(Double(1 - normalized), 2.0)
            }
        ))
    }
}
