//
//  QLearner.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

import Foundation

struct QLearningStep: Identifiable, Sendable {
    let id: UUID = UUID()
    let state: SensorInput
    let actionIndex: Int
    let reward: Double
    let nextState: SensorInput?
}

actor QLearner {
    let mainNetwork = NeuralNetworkBuilder(inputSize: 4)
        .dense(10, activation: .relu)
        .dense(10, activation: .relu)
        .dense(3, activation: .linear)
        .build(weightInitStrategy: .uniformXavier)
    
    private let targetNetwork = NeuralNetworkBuilder(inputSize: 4)
        .dense(10, activation: .relu)
        .dense(10, activation: .relu)
        .dense(3, activation: .linear)
        .build(weightInitStrategy: .uniformXavier)
    
    private let epsilonGreedy: Double
    private let gamma: Double
    private var expirienceBuffer: [QLearningStep] = []
    
    private let batchSize: Int
    private let simulationController: SimulationControlling?
    
    init(epsilonGreedy: Double, gamma: Double, batchSize: Int = 64, simulationController: SimulationControlling? = nil) {
        self.epsilonGreedy = epsilonGreedy
        self.gamma = gamma
        self.batchSize = batchSize
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
    
    func reportStep(currentState: SensorInput, nextState: SensorInput?, actionIndex: Int, didDie: Bool) {
        let reward = calculateReward(currentState: currentState, nextState: nextState, didDie: didDie)
        let step = QLearningStep(
            state: currentState,
            actionIndex: actionIndex,
            reward: reward,
            nextState: nextState
        )
        
        expirienceBuffer.append(step)
        // Also forward to a shared store for UI reporting
        Task {
            await QLearningStore.shared.append(step)
        }
        
        Task { [weak self] in
            await self?.flushIfNeeded()
        }
    }
    
    private func flushIfNeeded() async {
        guard expirienceBuffer.count >= batchSize else { return }
        let batch = expirienceBuffer
        expirienceBuffer.removeAll()

        // Capture the reference before any suspension to avoid sending across awaits
        let controller = simulationController
        // Pause on the main actor (async-safe)
        await controller?.pauseSimulation()

        defer {
            // Use a new task but capture the controller locally to avoid touching self
            Task { @MainActor [controller] in
                await controller?.resumeSimulation()
            }
        }

        await learn(from: batch)
    }
    
    // MARK: - Learning

    /// Compute DQN targets for a batch: if nextState is nil -> target = reward; else target = reward + gamma * max_a' Q_target(nextState, a')
    private func computeTargets(for batch: [QLearningStep]) -> [Double] {
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

    private func learn(from batch: [QLearningStep]) async {
        guard !batch.isEmpty else { return }

        // Predict Q(s, ·) for taken actions using main network
        var predictedQsForTakenActions: [Double] = []
        predictedQsForTakenActions.reserveCapacity(batch.count)
        for step in batch {
            let currentQ = mainNetwork.predict(inputs: step.state.normalized)
            predictedQsForTakenActions.append(currentQ[step.actionIndex])
        }

        // Compute DQN targets with target network
        let targets = computeTargets(for: batch)

        // Compute MSE loss for monitoring/training step
        let mseLoss = meanSquaredError(predictions: predictedQsForTakenActions, targets: targets)

        // Simulate work (placeholder for optimizer/backprop update)
        try? await Task.sleep(nanoseconds: 50_000_000)

        await MainActor.run {
            QLearningStore.shared.appendLoss(mseLoss)
        }
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

