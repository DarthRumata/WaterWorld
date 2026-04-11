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
    private(set) var batchLosses: [Double] = []
    private(set) var batchEpsilons: [Double] = []
    private(set) var lastLoss: Double = 0
    private(set) var batchRewards: [Double] = []
    private(set) var batchMaxQs: [Double] = []
    private(set) var episodeSurvivalRates: [Double] = []

    // Real-time metrics for UI
    private(set) var lastSurvivalRate: Double = 0
    private(set) var lastAvgReward: Double = 0
    private(set) var lastAvgMaxQ: Double = 0

    func append(_ step: QLearningExperience) {
        steps.append(step)
    }

    func appendLoss(_ loss: Double, epsilon: Double) {
        batchLosses.append(loss)
        batchEpsilons.append(epsilon)
        lastLoss = loss
    }
    
    func appendRewardTrend(_ avgReward: Double) {
        batchRewards.append(avgReward)
        lastAvgReward = avgReward
    }

    func appendMaxQTrend(_ avgMaxQ: Double) {
        batchMaxQs.append(avgMaxQ)
        lastAvgMaxQ = avgMaxQ
    }

    func appendSurvivalRate(_ rate: Double) {
        episodeSurvivalRates.append(rate)
        lastSurvivalRate = rate
    }

    func clear() {
        steps.removeAll()
        batchLosses.removeAll()
        batchEpsilons.removeAll()
        batchRewards.removeAll()
        batchMaxQs.removeAll()
        episodeSurvivalRates.removeAll()
    }
}
