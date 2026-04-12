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
    var learningRate: Double = 0.01
    var epsilonDecay: Double = 0.995
    var deltaWeight: Double = 0.05

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
    var onSetDeltaWeight: (Double) -> Void = { _ in }
    var onTapMetric: (MetricTab) -> Void = { _ in }
    var onSaveNetwork: () -> Void = {}
    var onLoadNetwork: () -> Void = {}
}
