//
//  AgentPolicy.swift
//  WaterWorld Shared
//

import Foundation

/// Shared actor that provides action selection for all organisms.
/// QLearner updates it after each training batch.
actor AgentPolicy {
    private var network: NeuralNetwork
    private var epsilon: Double

    init(network: NeuralNetwork, epsilon: Double) {
        self.network = network
        self.epsilon = epsilon
    }

    func provideActionIndex(for inputs: [Double], actionCount: Int) -> Int {
        if Double.random(in: 0..<1) < epsilon {
            return Int.random(in: 0..<actionCount)
        }
        let q = network.predict(inputs: inputs)
        return q.indices.max(by: { q[$0] < q[$1] }) ?? 0
    }

    func update(network: NeuralNetwork, epsilon: Double) {
        self.network = network
        self.epsilon = epsilon
    }
}
