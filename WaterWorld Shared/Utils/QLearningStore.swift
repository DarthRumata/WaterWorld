//
//  QLearningStore.swift
//  WaterWorld Shared
//
//  Central store for Q-learning steps to power reporting UI.
//

import Foundation

@MainActor
final class QLearningStore {
    static let shared = QLearningStore()

    private(set) var steps: [QLearningStep] = []
    private(set) var batchLosses: [Double] = []

    func append(_ step: QLearningStep) {
        steps.append(step)
    }

    func appendLoss(_ loss: Double) {
        batchLosses.append(loss)
    }

    func clear() {
        steps.removeAll()
        batchLosses.removeAll()
    }
}
