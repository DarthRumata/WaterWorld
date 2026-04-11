//
//  QLearner.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

import Foundation

struct QLearningExperience: Identifiable, Sendable {
    let id: UUID = UUID()
    let state: SensorInput
    let actionIndex: Int
    let reward: Double
    let nextState: SensorInput?
}

actor QLearner {
    static func makeNetwork() -> NeuralNetwork {
        NeuralNetworkBuilder(inputSize: 4)
            .dense(10, activation: .relu)
            .dense(10, activation: .relu)
            .dense(3, activation: .linear)
            .build(weightInitStrategy: .uniformXavier)
    }

    var mainNetwork = QLearner.makeNetwork()
    private var targetNetwork = QLearner.makeNetwork()
    
    private var networkUpdateHandler: (@Sendable (NeuralNetwork, Double) async -> Void)?

    private let batchSize: Int
	private var epsilonGreedy: Double
	private let gamma: Double
	private let learningRate: Double
	
    private let maxBufferSize: Int = 350000
    private let maxSurpriseBufferSize: Int = 50000
    private let trainInterval = 960
    private let epsilonMin: Double = 0.04
    private let epsilonDecay: Double = 0.995
    private let targetUpdateInterval: Int = 10
    private let surpriseRatio: Double = 0.25
    private let surpriseThreshold: Double = 2.0
    private let deathPenalty: Double = -120

    private var normalBuffer: [QLearningExperience] = []
    private var normalBufferIndex: Int = 0
    private var surpriseBuffer: [QLearningExperience] = []
    private var surpriseBufferIndex: Int = 0
    private var stepsSinceLastTrain = 0
    private var learningStepsCount = 0

    
    init(epsilonGreedy: Double, gamma: Double, batchSize: Int = 64, learningRate: Double = 0.01) {
        self.epsilonGreedy = epsilonGreedy
        self.gamma = gamma
        self.batchSize = batchSize
        self.learningRate = learningRate
    }

    var currentEpsilon: Double { epsilonGreedy }

    func setNetworkUpdateHandler(_ handler: @escaping @Sendable (NeuralNetwork, Double) async -> Void) {
        networkUpdateHandler = handler
    }
    
    func reportExperience(currentState: SensorInput, nextState: SensorInput?, actionIndex: Int, didDie: Bool) {
        let reward = calculateReward(nextState: nextState)
        let step = QLearningExperience(
            state: currentState,
            actionIndex: actionIndex,
            reward: reward,
            nextState: nextState
        )
        
        if normalBuffer.count < maxBufferSize {
            normalBuffer.append(step)
        } else {
            normalBuffer[normalBufferIndex] = step
            normalBufferIndex = (normalBufferIndex + 1) % maxBufferSize
        }

        stepsSinceLastTrain += 1

        if normalBuffer.count >= batchSize && stepsSinceLastTrain >= trainInterval {
			stepsSinceLastTrain = 0 // Сбрасываем счетчик
			
			Task { [weak self] in
				await self?.trainOnMiniBatch()
			}
		}
		
		// Also forward to a shared store for UI reporting
		Task {
			await QLearningStore.shared.append(step)
		}
    }
    
    private func trainOnMiniBatch() async {
        let wantedSurprise = Int(Double(batchSize) * surpriseRatio)
        let actualSurprise = min(wantedSurprise, surpriseBuffer.count)
        let normalCount = batchSize - actualSurprise
        var batch: [QLearningExperience] = []
        batch.reserveCapacity(batchSize)
        for _ in 0..<normalCount {
            if let step = normalBuffer.randomElement() { batch.append(step) }
        }
        for _ in 0..<actualSurprise {
            if let step = surpriseBuffer.randomElement() { batch.append(step) }
        }

        await learn(from: batch)
    }
    
    // MARK: - Learning

    /// Compute DQN targets for a batch: if nextState is nil -> target = reward; else target = reward + gamma * max_a' Q_target(nextState, a')
    private func computeTargets(for batch: [QLearningExperience]) -> [Double] {
        var targets: [Double] = []
        targets.reserveCapacity(batch.count)
        for step in batch {
            if let nextState = step.nextState {
                let nextQ = targetNetwork.predict(inputs: nextState.normalized)
                if let maxNextQ = nextQ.max() {
                    targets.append(step.reward + gamma * maxNextQ)
                } else {
                    targets.append(step.reward)
                }
            } else {
                targets.append(step.reward)
            }
        }
        return targets
    }

    /// Mean Squared Error between predictions and targets
    private func meanSquaredError(predictions: [Double], targets: [Double]) -> Double {
        guard !predictions.isEmpty, predictions.count == targets.count else { return 0 }
        var sumSquaredError: Double = 0
        for (p, t) in zip(predictions, targets) {
            let d = t - p
            sumSquaredError += d * d
        }
        return sumSquaredError / Double(predictions.count)
    }

    private func learn(from batch: [QLearningExperience]) async {
        guard !batch.isEmpty else { return }

        // Predict Q(s, ·) for taken actions using main network, also track max Q for monitoring
        var predictedQsForTakenActions: [Double] = []
        var maxQSum: Double = 0
        predictedQsForTakenActions.reserveCapacity(batch.count)
        for step in batch {
            let currentQ = mainNetwork.predict(inputs: step.state.normalized)
            predictedQsForTakenActions.append(currentQ[step.actionIndex])
            maxQSum += currentQ.max() ?? 0
        }

        // Compute DQN targets with target network
        let targets = computeTargets(for: batch)

        // Compute MSE loss for monitoring/training step
        let mseLoss = meanSquaredError(predictions: predictedQsForTakenActions, targets: targets)

        // Yield so other actor requests (e.g. neuralNetwork reads) can be served between phases
        await Task.yield()

        for (step, target) in zip(batch, targets) {
            let inputs = step.state.normalized
            let predicted = mainNetwork.predict(inputs: inputs)
            let tdError = abs(predicted[step.actionIndex] - target)
            var error = Array(repeating: 0.0, count: predicted.count)
            error[step.actionIndex] = predicted[step.actionIndex] - target
            mainNetwork.backward(error: error, inputs: inputs, learningRate: learningRate)

            if tdError > surpriseThreshold {
                if surpriseBuffer.count < maxSurpriseBufferSize {
                    surpriseBuffer.append(step)
                } else {
                    surpriseBuffer[surpriseBufferIndex] = step
                    surpriseBufferIndex = (surpriseBufferIndex + 1) % maxSurpriseBufferSize
                }
            }
        }
		
		learningStepsCount += 1
		epsilonGreedy = max(epsilonMin, epsilonGreedy * epsilonDecay)
        if learningStepsCount % targetUpdateInterval == 0 {
			targetNetwork = mainNetwork
		}

        let avgReward = batch.map { $0.reward }.reduce(0, +) / Double(batch.count)
        let avgMaxQ = maxQSum / Double(batch.count)

        let net = mainNetwork
        let eps = epsilonGreedy
        let handler = networkUpdateHandler
        Task { await handler?(net, eps) }

        Task { @MainActor in
            QLearningStore.shared.appendLoss(mseLoss, epsilon: eps)
            QLearningStore.shared.appendRewardTrend(avgReward)
            QLearningStore.shared.appendMaxQTrend(avgMaxQ)
        }
    }
    
    func applySnapshot(_ snapshot: NeuralNetworkSnapshot) throws {
        guard let network = NeuralNetwork(snapshot: snapshot) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        mainNetwork = network
        targetNetwork = network
    }
	
	private func calculateReward(nextState: SensorInput?) -> Double {
        guard let nextState else { return deathPenalty }
        return (nextState.energy / GlobalConstants.maxEnergy) * 2.0 - 1.0
	}
}

private func zip3<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
    zip(a, zip(b, c)).map { ($0.0, $0.1.0, $0.1.1) }
}

