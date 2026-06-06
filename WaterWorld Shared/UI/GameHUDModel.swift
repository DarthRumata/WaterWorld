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
    var epsilon: Double = 0.0
    var gamma: Double = HyperparamSpecs.gamma.defaultValue
    var tau: Double = HyperparamSpecs.tau.defaultValue
    var learningRate: Double = HyperparamSpecs.learningRate.defaultValue
    var epsilonDecay: Double = HyperparamSpecs.epsilonDecay.defaultValue
    // MARK: - Adam params
    var isAdamEnabled: Bool = true
    var adamBeta1: Double = HyperparamSpecs.adamBeta1.defaultValue
    var adamBeta2: Double = HyperparamSpecs.adamBeta2.defaultValue
    var adamEps: Double = HyperparamSpecs.adamEps.defaultValue
    // MARK: - Simulation params
    var dodgeCost: Double = GlobalConstants.predationDodgeCost
    // MARK: - Reward params
    var deathPenalty: Double = 0.0
    var isStateRewardEnabled: Bool = true
    var isDeltaRewardEnabled: Bool = true
    var nStep: Int = Int(HyperparamSpecs.nStep.defaultValue)

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
    var onSetEpsilon: (Double) -> Void = { _ in }
    var onSetEpsilonDecay: (Double) -> Void = { _ in }
    var onSetDodgeCost: (Double) -> Void = { _ in }
    var onToggleStateReward: (Bool) -> Void = { _ in }
    var onToggleDeltaReward: (Bool) -> Void = { _ in }
    var networkArchitecture: [Int] = QLearner.defaultHiddenLayers
    var onApplyArchitecture: ([Int]) -> Void = { _ in }
    var onToggleAdam: (Bool) -> Void = { _ in }
    var onSetAdamBeta1: (Double) -> Void = { _ in }
    var onSetAdamBeta2: (Double) -> Void = { _ in }
    var onSetAdamEps: (Double) -> Void = { _ in }
    var onSetNStep: (Int) -> Void = { _ in }
    var onTapMetric: (MetricTab) -> Void = { _ in }
    var onSaveNetwork: () -> Void = {}
    var onLoadNetwork: () -> Void = {}
    var onDiagnostics: () -> Void = {}
}
