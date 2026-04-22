//
//  QLearner.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

import Foundation

struct QLearningExperience: Identifiable, Sendable {
    let id: UUID = UUID()
    let state: OrganismState
    let actionIndex: Int
    let reward: Double
    let nextState: OrganismState?
}

actor QLearner {
    static func makeNetwork() -> NeuralNetwork {
        NeuralNetworkBuilder(inputSize: 5)
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
    private(set) var learningRate: Double
    private var costFunction: any CostFunction

    private let maxBufferSize: Int = 550000
    private let maxSurpriseBufferSize: Int = 50000
    private let trainInterval = 960
    private let epsilonMin: Double = 0.04
    private(set) var epsilonDecay: Double
    private let surpriseRatio: Double = 0.25
    private var tdStats = SurpriseThresholdTracker()
    private(set) var deathPenalty: Double = -1.0
    private(set) var tau: Double = 0.005
    private let diagnosticsMinSteps: Int = 10
    private let diagnosticsStreakThreshold: Int = 3

    private(set) var adamBeta1: Double = 0.9
    private(set) var adamBeta2: Double = 0.99
    private(set) var adamEps: Double = 1e-8
    private(set) var isAdamEnabled: Bool = true

    private(set) var isLearningEnabled: Bool = false

    private var normalBuffer: [QLearningExperience] = []
    private var normalBufferIndex: Int = 0
    private var surpriseBuffer: [QLearningExperience] = []
    private var surpriseBufferIndex: Int = 0
    private var stepsSinceLastTrain = 0
    private var learningStepsCount = 0
    private var warningStreaks: [String: Int] = [:]
    private var isTraining = false

    init(
        epsilonGreedy: Double,
        gamma: Double,
        batchSize: Int,
        learningRate: Double,
        epsilonDecay: Double,
        costFunction: any CostFunction,
        networkUpdateHandler: (@Sendable (NeuralNetwork, Double) async -> Void)?,
        sustainedWarningHandler: (@Sendable ([LearningWarning]) async -> Void)?
    ) {
        self.epsilonGreedy = epsilonGreedy
        self.gamma = gamma
        self.batchSize = batchSize
        self.learningRate = learningRate
        self.epsilonDecay = epsilonDecay
        self.costFunction = costFunction
        self.networkUpdateHandler = networkUpdateHandler
        self.sustainedWarningHandler = sustainedWarningHandler
    }

    var currentEpsilon: Double { epsilonGreedy }

    func setLearningEnabled(_ enabled: Bool) { isLearningEnabled = enabled }

    func setCostFunction(_ type: CostFunctionType) { costFunction = type.make() }
    func setGamma(_ value: Double)        { gamma        = min(0.999,  max(0.01,   value)) }
    func setTau(_ value: Double)          { tau          = min(0.1,    max(0.001,  value)) }
    func setDeathPenalty(_ value: Double)  { deathPenalty  = min(0.0,   max(-1.0,  value)) }
    func setLearningRate(_ value: Double) { learningRate = min(0.1,    max(0.0001, value)) }
    func setEpsilonDecay(_ value: Double) { epsilonDecay = min(0.9999, max(0.99,   value)) }
    func setAdamBeta1(_ value: Double)    { adamBeta1 = min(0.999,  max(0.8,   value)); mainNetwork.resetAdamState() }
    func setAdamBeta2(_ value: Double)    { adamBeta2 = min(0.9999, max(0.9,   value)); mainNetwork.resetAdamState() }
    func setAdamEps(_ value: Double)      { adamEps   = min(1e-4,   max(1e-10, value)); mainNetwork.resetAdamState() }
    func setAdamEnabled(_ enabled: Bool)  { isAdamEnabled = enabled; mainNetwork.resetAdamState() }
    
    func reportExperience(currentState: OrganismState, nextState: OrganismState?, actionIndex: Int) {
        guard isLearningEnabled else { return }
        let reward = calculateReward(currentState: currentState, nextState: nextState)
        let experience = QLearningExperience(
            state: currentState,
            actionIndex: actionIndex,
            reward: reward,
            nextState: nextState
        )
		
		Task {
			await QLearningStore.shared.append(experience)
		}
        
        if normalBuffer.count < maxBufferSize {
            normalBuffer.append(experience)
        } else {
            normalBuffer[normalBufferIndex] = experience
            normalBufferIndex = (normalBufferIndex + 1) % maxBufferSize
        }

        guard !isTraining else { return }

        stepsSinceLastTrain += 1

        if normalBuffer.count >= batchSize && stepsSinceLastTrain >= trainInterval {
            stepsSinceLastTrain = 0
            isTraining = true
            Task { [weak self] in
                await self?.trainOnMiniBatch()
            }
        }
    }
	
    func applySnapshot(_ snapshot: NeuralNetworkSnapshot) throws {
        guard let network = NeuralNetwork(snapshot: snapshot) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        mainNetwork = network
        targetNetwork = network

        let net = mainNetwork
        let eps = epsilonGreedy
        Task { await networkUpdateHandler?(net, eps) }
        Task { @MainActor in
            QLearningStore.shared.updateCurrentNetwork(net)
        }
    }
    
    // MARK: - Learning
	
	private func trainOnMiniBatch() async {
		let wantedSurprise = Int(Double(batchSize) * surpriseRatio)
		let actualSurprise = min(wantedSurprise, surpriseBuffer.count)
		let normalCount = batchSize - actualSurprise
		var batch: [QLearningExperience] = []
		batch.reserveCapacity(batchSize)
		for _ in 0..<normalCount {
			if let experience = normalBuffer.randomElement() { batch.append(experience) }
		}
		for _ in 0..<actualSurprise {
			if let experience = surpriseBuffer.randomElement() { batch.append(experience) }
		}

		learn(from: batch)
        isTraining = false
	}

    private func learn(from batch: [QLearningExperience]) {
        guard !batch.isEmpty else { return }

        let (predictedQs, targets, maxQSum) = computeBatchPredictions(batch: batch)
        let mseLoss = costFunction.loss(predictions: predictedQs, targets: targets)

        applyBackprop(batch: batch, targets: targets)

        learningStepsCount += 1
        epsilonGreedy = max(epsilonMin, epsilonGreedy * epsilonDecay)
        // Soft update: target slowly tracks main (τ=0.005 ≈ 0.5% per step).
        // Keeps training stable — no sudden weight jumps unlike hard copy every N steps.
        targetNetwork.polyakBlend(toward: mainNetwork, tau: tau)

        let eps = epsilonGreedy
        let net = mainNetwork
        Task { await networkUpdateHandler?(net, eps) }

        let sustainedWarnings = diagnoseLearningHealth(batch: batch)
        let avgReward = batch.map { $0.reward }.reduce(0, +) / Double(batch.count)
        let avgMaxQ = maxQSum / Double(batch.count)

        Task { @MainActor in
            QLearningStore.shared.appendLoss(mseLoss, epsilon: eps)
            QLearningStore.shared.appendRewardTrend(avgReward)
            QLearningStore.shared.appendMaxQTrend(avgMaxQ)
            QLearningStore.shared.updateLearningWarnings(sustainedWarnings)
            QLearningStore.shared.updateCurrentNetwork(net)
        }
        if !sustainedWarnings.isEmpty {
            Task { await self.sustainedWarningHandler?(sustainedWarnings) }
        }
    }

    /// Single forward pass over the batch: computes current Q-values (main network),
    /// Double DQN targets (main selects action, target evaluates), and avg max Q for monitoring.
    private func computeBatchPredictions(
        batch: [QLearningExperience]
    ) -> (predictedQs: [Double], targets: [Double], maxQSum: Double) {
        var predictedQs: [Double] = []
        var targets: [Double] = []
        var maxQSum: Double = 0
        predictedQs.reserveCapacity(batch.count)
        targets.reserveCapacity(batch.count)

        for experience in batch {
            let currentQ = mainNetwork.predict(inputs: experience.state.normalized)
            predictedQs.append(currentQ[experience.actionIndex])
            maxQSum += currentQ.max() ?? 0

            if let nextState = experience.nextState {
                // Double DQN: main network selects action, target network evaluates it.
                // Decouples action selection from value estimation → reduces overestimation bias.
                let nextMainQ = mainNetwork.predict(inputs: nextState.normalized)
                let bestAction = nextMainQ.indices.max(by: { nextMainQ[$0] < nextMainQ[$1] }) ?? 0
                let nextTargetQ = targetNetwork.predict(inputs: nextState.normalized)
                targets.append(experience.reward + gamma * nextTargetQ[bestAction])
            } else {
                targets.append(experience.reward)
            }
        }
        return (predictedQs, targets, maxQSum)
    }

    /// Backprop loop: updates main network weights and populates the surprise buffer.
    /// Uses fresh predict() per step so each gradient reflects the current network state
    /// after previous updates — preserving the original sequential update dynamics.
    private func applyBackprop(batch: [QLearningExperience], targets: [Double]) {
        let actionCount = OrganismModel.Action.allCases.count
        for (experience, target) in zip(batch, targets) {
            let inputs = experience.state.normalized
            let predicted = mainNetwork.predict(inputs: inputs)
            let prediction = predicted[experience.actionIndex]
            let isSurprising = tdStats.observe(prediction: prediction, target: target)
            let grad = costFunction.gradient(prediction: prediction, target: target)
            var error = Array(repeating: 0.0, count: actionCount)
            error[experience.actionIndex] = grad
            mainNetwork.backward(error: error, inputs: inputs, learningRate: learningRate, beta1: adamBeta1, beta2: adamBeta2, eps: adamEps, useAdam: isAdamEnabled)

            if isSurprising {
                if surpriseBuffer.count < maxSurpriseBufferSize {
                    surpriseBuffer.append(experience)
                } else {
                    surpriseBuffer[surpriseBufferIndex] = experience
                    surpriseBufferIndex = (surpriseBufferIndex + 1) % maxSurpriseBufferSize
                }
            }
        }
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

    private func calculateReward(currentState: OrganismState, nextState: OrganismState?) -> Double {
        guard let nextState else { return deathPenalty }

        var r = GlobalConstants.rewardTickSurvivalBonus

        let dE = nextState.energy - currentState.energy
        if dE > 0 {
            r += min(dE / GlobalConstants.rewardEnergyDeltaScale, 0.5)
        } else if dE < 0 {
            r += max(dE / GlobalConstants.rewardEnergyLossPenaltyScale, -0.5)
        }

        if nextState.energy < GlobalConstants.rewardCriticalEnergyThreshold {
            r -= (GlobalConstants.rewardCriticalEnergyThreshold - nextState.energy) / GlobalConstants.rewardEnergyDeltaScale
        } else if nextState.energy < GlobalConstants.rewardWarningEnergyThreshold {
            r -= (GlobalConstants.rewardWarningEnergyThreshold - nextState.energy) / GlobalConstants.rewardWarningPenaltyScale
        }

        return clamp(r, -1.0, 1.0)
    }
}

private func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

private func zip3<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
    zip(a, zip(b, c)).map { ($0.0, $0.1.0, $0.1.1) }
}

