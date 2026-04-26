import Foundation

actor AgentPolicy {
    struct Snapshot: Sendable {
        let network: NeuralNetwork
        let epsilon: Double
    }

    private var network: NeuralNetwork
    private var epsilon: Double

    init(network: NeuralNetwork, epsilon: Double) {
        self.network = network
        self.epsilon = epsilon
    }

    func currentSnapshot() -> Snapshot { Snapshot(network: network, epsilon: epsilon) }

    func update(network: NeuralNetwork, epsilon: Double) {
        self.network = network
        self.epsilon = epsilon
    }
}
