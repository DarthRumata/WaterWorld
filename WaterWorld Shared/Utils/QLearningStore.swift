//
//  QLearningStore.swift
//  WaterWorld Shared
//
//  Central store for Q-learning steps to power reporting UI.
//

import Foundation
import Observation

@MainActor
@Observable
final class QLearningStore {
    static let shared = QLearningStore()

    private(set) var steps: [QLearningExperience] = []
    private(set) var batchRelativeLosses: [Double] = []
    private(set) var batchEpsilons: [Double] = []
    private(set) var batchDays: [Int] = []
    var currentDay: Int = 0
    private(set) var lastRelativeLoss: Double = 0
    private(set) var batchRewards: [Double] = []
    private(set) var batchMaxQs: [Double] = []
    private(set) var batchTargetDivergences: [Double] = []
    private(set) var batchTrainDurations: [Double] = []
    private(set) var batchAdamLRs: [Double] = []
    private(set) var batchUpdateRatios: [Double] = []
    private(set) var batchTickRewards: [Double] = []
    private(set) var batchDeltaRewards: [Double] = []
    private(set) var batchStateRewards: [Double] = []

    // Reward diagnostics per batch
    private(set) var batchBadRewardRatio: [Double] = []       // % healthy-energy steps with negative reward
    private(set) var dailyHungerDeaths: [Int] = []
    private(set) var dailyPredatorDeaths: [Int] = []
    private var currentDayHungerDeaths: Int = 0
    private var currentDayPredatorDeaths: Int = 0
    /// Day index at which each episode started, keyed by episode number.
    private(set) var episodeBoundaries: [Int: Int] = [:]

    private(set) var dailyMedianLifespans: [Double] = []
    private var currentDayLifespans: [Int] = []

    private(set) var dailyNightEntryEnergy: [Double] = []

    var onLifespanMilestone: ((Int) -> Void)?
    private(set) var bestAutoSavedLifespan: Int = UserDefaults.standard.integer(forKey: "bestAutoSavedLifespan")

    // Real-time metrics for UI
    private(set) var lastAvgReward: Double = 0
    private(set) var lastAvgMaxQ: Double = 0
    // Theoretical Q-value bounds (updated each training batch)
    private(set) var qRefMax: Double = 0      // maxR / (1-γ)
    private(set) var qRefMin: Double = 0      // minR / (1-γ)
    private(set) var learningWarnings: [LearningWarning] = []
    private(set) var currentNetwork: NeuralNetwork?
    private(set) var networkUpdateCount: Int = 0

    func append(_ step: QLearningExperience) {
        steps.append(step)
    }

    func appendLoss(_ loss: Double, epsilon: Double, relativeLoss: Double) {
        batchRelativeLosses.append(relativeLoss)
        batchEpsilons.append(epsilon)
        batchDays.append(currentDay)
        lastRelativeLoss = relativeLoss
    }
    
    func appendRewardTrend(_ avgReward: Double) {
        batchRewards.append(avgReward)
        lastAvgReward = avgReward
    }

    func updateLearningWarnings(_ warnings: [LearningWarning]) {
        learningWarnings = warnings
    }

    func updateCurrentNetwork(_ network: NeuralNetwork) {
        currentNetwork = network
        networkUpdateCount += 1
    }

    func appendMaxQTrend(_ avgMaxQ: Double) {
        batchMaxQs.append(avgMaxQ)
        lastAvgMaxQ = avgMaxQ
    }

    func appendTargetDivergence(_ d: Double) {
        batchTargetDivergences.append(d)
    }

    func appendTrainDuration(_ ms: Double) {
        batchTrainDurations.append(ms)
    }

    func appendAdamLR(_ lr: Double) {
        batchAdamLRs.append(lr)
    }

    func appendUpdateRatio(_ ratio: Double) {
        batchUpdateRatios.append(ratio)
    }

    func appendRewardComponents(tick: Double, delta: Double, state: Double) {
        batchTickRewards.append(tick)
        batchDeltaRewards.append(delta)
        batchStateRewards.append(state)
    }

    func updateQReferences(gamma: Double, deathPenalty: Double) {
        let maxR = tanh(GlobalConstants.rewardTickSurvivalBonus + 0.5 + 0.2)
        let invGamma = max(1e-6, 1.0 - gamma)
        qRefMax = maxR / invGamma
        qRefMin = deathPenalty / invGamma
    }

    func appendRewardDiagnostics(badRatio: Double) {
        batchBadRewardRatio.append(badRatio)
    }

    func recordEpisodeBoundary(episode: Int) {
        episodeBoundaries[episode] = dailyHungerDeaths.count
    }

    func recordDeath(cause: CauseOfDeath) {
        switch cause {
        case .energyDepletion: currentDayHungerDeaths += 1
        case .predation: currentDayPredatorDeaths += 1
        }
    }

    func recordLifespan(days: Int) {
        currentDayLifespans.append(days)
        if days >= GlobalConstants.autoSaveLifespanThreshold && days > bestAutoSavedLifespan {
            bestAutoSavedLifespan = days
            UserDefaults.standard.set(days, forKey: "bestAutoSavedLifespan")
            onLifespanMilestone?(days)
        }
    }

    func recordNightEntry(avgEnergy: Double) {
        dailyNightEntryEnergy.append(avgEnergy)
    }

    func advanceDay(to day: Int) {
        dailyHungerDeaths.append(currentDayHungerDeaths)
        dailyPredatorDeaths.append(currentDayPredatorDeaths)
        currentDayHungerDeaths = 0
        currentDayPredatorDeaths = 0

        let median = medianLifespan(currentDayLifespans)
        dailyMedianLifespans.append(median)
        currentDayLifespans.removeAll()

        currentDay = day
    }

    func clear() {
        steps.removeAll()
        batchRelativeLosses.removeAll()
        batchEpsilons.removeAll()
        batchDays.removeAll()
        batchRewards.removeAll()
        batchMaxQs.removeAll()
        batchTargetDivergences.removeAll()
        batchTrainDurations.removeAll()
        batchAdamLRs.removeAll()
        batchUpdateRatios.removeAll()
        batchTickRewards.removeAll()
        batchDeltaRewards.removeAll()
        batchStateRewards.removeAll()
        batchBadRewardRatio.removeAll()
        dailyHungerDeaths.removeAll()
        dailyPredatorDeaths.removeAll()
        currentDayHungerDeaths = 0
        currentDayPredatorDeaths = 0
        dailyMedianLifespans.removeAll()
        currentDayLifespans.removeAll()
        dailyNightEntryEnergy.removeAll()
        currentDay = 0
        episodeBoundaries.removeAll()
        lastRelativeLoss = 0
        lastAvgReward = 0
        lastAvgMaxQ = 0
        learningWarnings = []
        currentNetwork = nil
        networkUpdateCount = 0
    }

    private func medianLifespan(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? Double(sorted[mid - 1] + sorted[mid]) / 2.0
            : Double(sorted[mid])
    }
}
