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
    
    private let networkUpdateHandler: (@Sendable (NeuralNetwork, Double) async -> Void)?
    private let sustainedWarningHandler: (@Sendable ([LearningWarning]) async -> Void)?

    private let batchSize: Int
	private var epsilonGreedy: Double
    private(set) var gamma: Double
	private let learningRate: Double
    private(set) var deltaWeight: Double
    private var costFunction: any CostFunction
    private let energyCalculator = EnergyCalculator()

    private let maxBufferSize: Int = 550000
    private let maxSurpriseBufferSize: Int = 50000
    private let trainInterval = 960
    private let epsilonMin: Double = 0.04
    private let epsilonDecay: Double = 0.995
    private let surpriseRatio: Double = 0.25
    private let surpriseThreshold: Double = 2.0
    private let deathPenalty: Double = -80
    private(set) var tau: Double = 0.005
    private let diagnosticsMinSteps: Int = 10
    private let diagnosticsStreakThreshold: Int = 3

    private var normalBuffer: [QLearningExperience] = []
    private var normalBufferIndex: Int = 0
    private var surpriseBuffer: [QLearningExperience] = []
    private var surpriseBufferIndex: Int = 0
    private var stepsSinceLastTrain = 0
    private var learningStepsCount = 0
    private var warningStreaks: [String: Int] = [:]

    init(
        epsilonGreedy: Double,
        gamma: Double,
        batchSize: Int,
        learningRate: Double,
        deltaWeight: Double,
        costFunction: any CostFunction,
        networkUpdateHandler: (@Sendable (NeuralNetwork, Double) async -> Void)?,
        sustainedWarningHandler: (@Sendable ([LearningWarning]) async -> Void)?
    ) {
        self.epsilonGreedy = epsilonGreedy
        self.gamma = gamma
        self.batchSize = batchSize
        self.learningRate = learningRate
        self.deltaWeight = deltaWeight
        self.costFunction = costFunction
        self.networkUpdateHandler = networkUpdateHandler
        self.sustainedWarningHandler = sustainedWarningHandler
    }

    var currentEpsilon: Double { epsilonGreedy }

    func setCostFunction(_ type: CostFunctionType) { costFunction = type.make() }
    func setGamma(_ value: Double) { gamma = min(0.999, max(0.01, value)) }
    func setTau(_ value: Double) { tau = min(0.1, max(0.001, value)) }
    func setDeltaWeight(_ value: Double) { deltaWeight = min(1.0, max(0.0, value)) }
    
    func reportExperience(currentState: SensorInput, nextState: SensorInput?, actionIndex: Int, didDie: Bool) {
        let reward = calculateReward(currentState: currentState, nextState: nextState)
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

        // Compute loss for monitoring/training step
        let mseLoss = costFunction.loss(predictions: predictedQsForTakenActions, targets: targets)

        // Yield so other actor requests (e.g. neuralNetwork reads) can be served between phases
        await Task.yield()

        for (step, target) in zip(batch, targets) {
            let inputs = step.state.normalized
            let predicted = mainNetwork.predict(inputs: inputs)
            let grad = costFunction.gradient(prediction: predicted[step.actionIndex], target: target)
            let tdError = abs(grad)
            var error = Array(repeating: 0.0, count: predicted.count)
            error[step.actionIndex] = grad
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
        // Soft update: target slowly tracks main (τ=0.005 ≈ 0.5% per step).
        // Keeps training stable — no sudden weight jumps unlike hard copy every N steps.
        targetNetwork.polyakBlend(toward: mainNetwork, tau: tau)

        let avgReward = batch.map { $0.reward }.reduce(0, +) / Double(batch.count)
        let avgMaxQ = maxQSum / Double(batch.count)

        let net = mainNetwork
        let eps = epsilonGreedy
        let handler = networkUpdateHandler
        Task { await handler?(net, eps) }

        let sustainedWarnings = diagnoseLearningHealth(batch: batch)
        let warningHandler = sustainedWarningHandler

        Task { @MainActor in
            QLearningStore.shared.appendLoss(mseLoss, epsilon: eps)
            QLearningStore.shared.appendRewardTrend(avgReward)
            QLearningStore.shared.appendMaxQTrend(avgMaxQ)
            QLearningStore.shared.updateLearningWarnings(sustainedWarnings)
        }

        if !sustainedWarnings.isEmpty {
            Task { await warningHandler?(sustainedWarnings) }
        }
    }
    
    func applySnapshot(_ snapshot: NeuralNetworkSnapshot) throws {
        guard let network = NeuralNetwork(snapshot: snapshot) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        mainNetwork = network
        targetNetwork = network
    }
	
    private func diagnoseLearningHealth(batch: [QLearningExperience]) -> [LearningWarning] {
        guard learningStepsCount >= diagnosticsMinSteps else { return [] }

        let sampleInputs = batch.prefix(16).map { $0.state.normalized }
        let detected = mainNetwork.healthCheck(sampleInputs: Array(sampleInputs))

        // Increment streak for detected warnings, reset for cleared ones
        var updatedStreaks: [String: Int] = [:]
        for warning in detected {
            updatedStreaks[warning.description] = (warningStreaks[warning.description] ?? 0) + 1
        }
        warningStreaks = updatedStreaks

        return detected.filter { (warningStreaks[$0.description] ?? 0) >= diagnosticsStreakThreshold }
    }

    private func calculateReward(currentState: SensorInput, nextState: SensorInput?) -> Double {
        guard let nextState else { return deathPenalty }

        // Absolute wellbeing: how full is the organism right now? ∈ [0, 1]
        let absolute = nextState.energy / GlobalConstants.maxEnergy

        // Normalized sensation: how much did energy change this tick?
        // Asymmetric bounds: gain is harder to achieve than loss, so each direction
        // is normalized independently to keep the full [-1, 1] range meaningful.
        let delta = nextState.energy - currentState.energy
        let normalizedDelta = delta >= 0
            ? min(delta / energyCalculator.maxGainPerTick, 1.0)   // ∈ [0,  1]
            : max(delta / energyCalculator.maxLossPerTick, -1.0)  // ∈ [-1, 0]

        // Alpha blend: deltaWeight=0 → pure survival signal, deltaWeight=1 → pure sensation
        return (1.0 - deltaWeight) * absolute + deltaWeight * normalizedDelta
    }
}

private func zip3<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
    zip(a, zip(b, c)).map { ($0.0, $0.1.0, $0.1.1) }
}

