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
    var mainNetwork = NeuralNetworkBuilder(inputSize: 4)
        .dense(10, activation: .relu)
        .dense(10, activation: .relu)
        .dense(3, activation: .linear)
        .build(weightInitStrategy: .uniformXavier)
    
    private var targetNetwork = NeuralNetworkBuilder(inputSize: 4)
        .dense(10, activation: .relu)
        .dense(10, activation: .relu)
        .dense(3, activation: .linear)
        .build(weightInitStrategy: .uniformXavier)
    
    private let batchSize: Int
	private var epsilonGreedy: Double
	private let gamma: Double
	private let learningRate: Double
    private let simulationController: SimulationControlling?
	
	private let maxBufferSize: Int = 100000
	private let trainInterval = 960
	private let epsilonMin: Double = 0.01
	private let epsilonDecay: Double = 0.995
	private let targetUpdateInterval: Int = 100
	
	private var expirienceBuffer: [QLearningExperience] = []
	private var stepsSinceLastTrain = 0
	private var learningStepsCount = 0

    
    init(epsilonGreedy: Double, gamma: Double, batchSize: Int = 64, learningRate: Double = 0.01, simulationController: SimulationControlling? = nil) {
        self.epsilonGreedy = epsilonGreedy
        self.gamma = gamma
        self.batchSize = batchSize
        self.learningRate = learningRate
        self.simulationController = simulationController
    }
    
    func provideActionIndex(for input: SensorInput) -> Int {
        if Double.random(in: 0..<1) < epsilonGreedy {
            return Int.random(in: 0..<OrganismModel.Action.allCases.count)
        }
        
        let inputs = input.normalized
        let q = mainNetwork.predict(inputs: inputs)
        
        var bestQIndex = 0
        var maxQ = Double.leastNormalMagnitude
        for (i, maxQForAction) in q.enumerated() {
            if maxQForAction > maxQ {
                maxQ = maxQForAction
                bestQIndex = i
            }
        }
        return bestQIndex
    }
    
    func reportExperience(currentState: SensorInput, nextState: SensorInput?, actionIndex: Int, didDie: Bool) {
        let reward = calculateReward(currentState: currentState, nextState: nextState, didDie: didDie)
        let step = QLearningExperience(
            state: currentState,
            actionIndex: actionIndex,
            reward: reward,
            nextState: nextState
        )
        
        expirienceBuffer.append(step)
		
		if expirienceBuffer.count > maxBufferSize {
			expirienceBuffer.removeFirst()
		}
			
		stepsSinceLastTrain += 1
        
		if expirienceBuffer.count >= batchSize && stepsSinceLastTrain >= trainInterval {
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
		var batch: [QLearningExperience] = []
		for _ in 0..<batchSize {
			if let randomStep = expirienceBuffer.randomElement() {
				batch.append(randomStep)
			}
		}

        // Capture the reference before any suspension to avoid sending across awaits
        let controller = simulationController
        // Pause on the main actor (async-safe)
        await controller?.startTraining()

        defer {
            Task { @MainActor [controller] in
                await controller?.finishTraining()
            }
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
            var error = Array(repeating: 0.0, count: predicted.count)
            error[step.actionIndex] = predicted[step.actionIndex] - target
            mainNetwork.backward(error: error, inputs: inputs, learningRate: learningRate)
        }
		
		learningStepsCount += 1
		epsilonGreedy = max(epsilonMin, epsilonGreedy * epsilonDecay)
		// Жестко копируем веса каждые N шагов (например, 10 или 50)
		if learningStepsCount % 10 == 0 {
			targetNetwork = mainNetwork
		}

        let avgReward = batch.map { $0.reward }.reduce(0, +) / Double(batch.count)
        let avgMaxQ = maxQSum / Double(batch.count)

        Task { @MainActor in
            QLearningStore.shared.appendLoss(mseLoss)
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

    private func calculateReward(currentState: SensorInput, nextState: SensorInput?, didDie: Bool) -> Double {
        if let nextState {
            let energyDelta = nextState.energy - currentState.energy
            if energyDelta < 0 {
                return energyDelta * 0.5
            } else {
                return energyDelta
            }
        } else {
            return currentState.energy > 0 && !didDie ? 100 : -100
        }
    }
}

