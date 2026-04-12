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
    private(set) var batchDays: [Int] = []
    var currentDay: Int = 0
    private(set) var lastLoss: Double = 0
    private(set) var batchRewards: [Double] = []
    private(set) var batchMaxQs: [Double] = []
    private(set) var dailyHungerDeaths: [Int] = []
    private(set) var dailyPredatorDeaths: [Int] = []
    private var currentDayHungerDeaths: Int = 0
    private var currentDayPredatorDeaths: Int = 0
    /// Day index at which each episode started, keyed by episode number.
    private(set) var episodeBoundaries: [Int: Int] = [:]

    // Real-time metrics for UI
    private(set) var lastAvgReward: Double = 0
    private(set) var lastAvgMaxQ: Double = 0
    private(set) var learningWarnings: [LearningWarning] = []

    func append(_ step: QLearningExperience) {
        steps.append(step)
    }

    func appendLoss(_ loss: Double, epsilon: Double) {
        batchLosses.append(loss)
        batchEpsilons.append(epsilon)
        batchDays.append(currentDay)
        lastLoss = loss
    }
    
    func appendRewardTrend(_ avgReward: Double) {
        batchRewards.append(avgReward)
        lastAvgReward = avgReward
    }

    func updateLearningWarnings(_ warnings: [LearningWarning]) {
        learningWarnings = warnings
    }

    func appendMaxQTrend(_ avgMaxQ: Double) {
        batchMaxQs.append(avgMaxQ)
        lastAvgMaxQ = avgMaxQ
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

    func advanceDay(to day: Int) {
        dailyHungerDeaths.append(currentDayHungerDeaths)
        dailyPredatorDeaths.append(currentDayPredatorDeaths)
        currentDayHungerDeaths = 0
        currentDayPredatorDeaths = 0
        currentDay = day
    }

    func clear() {
        steps.removeAll()
        batchLosses.removeAll()
        batchEpsilons.removeAll()
        batchDays.removeAll()
        batchRewards.removeAll()
        batchMaxQs.removeAll()
        dailyHungerDeaths.removeAll()
        dailyPredatorDeaths.removeAll()
        currentDayHungerDeaths = 0
        currentDayPredatorDeaths = 0
        episodeBoundaries.removeAll()
    }
}
