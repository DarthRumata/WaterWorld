//
//  GameHUDModel.swift
//  WaterWorld Shared
//

import Foundation
import Observation

@MainActor
@Observable
final class GameHUDModel {
    // MARK: - State
    var dayCount: Int = 0
    var episodeNumber: Int = 0
    var episodeDayCount: Int = 0
    var organismsCount: Int = 0
    var simulationSpeed: TimeInterval = 1.0
    var lightLevel: Double = 0
    var dayProgress: Double = 0
    var gameState: GameState = .stopped
    var simulationMode: SimulationMode = .normal
    var predatorsIntensity: PredatorsIntensity = .medium
    var costFunctionType: CostFunctionType = .mse

    // MARK: - Learning params
    var gamma: Double = 0.99
    var tau: Double = 0.005
    var learningRate: Double = 0.001
    var epsilonDecay: Double = 0.995
    // MARK: - Adam params
    var isAdamEnabled: Bool = true
    var adamBeta1: Double = 0.9
    var adamBeta2: Double = 0.99
    var adamEps: Double = 1e-8
    // MARK: - Simulation params
    var dodgeEnergyRequired: Double = GlobalConstants.predationDodgeEnergyRequired
    var dodgeCost: Double = GlobalConstants.predationDodgeCost
    // MARK: - Reward params
    var deathPenalty: Double = -1.0

    // MARK: - Actions
    var onRestart: () -> Void = {}
    var onIncreaseSpeed: () -> Void = {}
    var onDecreaseSpeed: () -> Void = {}
    var onPause: () -> Void = {}
    var onReport: () -> Void = {}
    var onToggleMode: () -> Void = {}
    var onSelectPredatorsIntensity: (PredatorsIntensity) -> Void = { _ in }
    var onSelectCostFunction: (CostFunctionType) -> Void = { _ in }
    var onSetGamma: (Double) -> Void = { _ in }
    var onSetTau: (Double) -> Void = { _ in }
    var onSetLearningRate: (Double) -> Void = { _ in }
    var onSetEpsilonDecay: (Double) -> Void = { _ in }
    var onSetDodgeEnergyRequired: (Double) -> Void = { _ in }
    var onSetDodgeCost: (Double) -> Void = { _ in }
    var onSetDeathPenalty: (Double) -> Void = { _ in }
    var onToggleAdam: (Bool) -> Void = { _ in }
    var onSetAdamBeta1: (Double) -> Void = { _ in }
    var onSetAdamBeta2: (Double) -> Void = { _ in }
    var onSetAdamEps: (Double) -> Void = { _ in }
    var onTapMetric: (MetricTab) -> Void = { _ in }
    var onSaveNetwork: () -> Void = {}
    var onLoadNetwork: () -> Void = {}
}
