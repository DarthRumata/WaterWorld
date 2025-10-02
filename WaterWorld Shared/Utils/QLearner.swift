//
//  QLearner.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

private struct QLearningStep {
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
    
    init(epsilonGreedy: Double, gamma: Double) {
        self.epsilonGreedy = epsilonGreedy
        self.gamma = gamma
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
    
    func reportStep(currentState: SensorInput, nextState: SensorInput?, actionIndex: Int) {
        let reward = calculateReward(currentState: currentState, nextState: nextState)
        let step = QLearningStep(
            state: currentState,
            actionIndex: actionIndex,
            reward: reward,
            nextState: nextState
        )
        
        expirienceBuffer.append(step)
    }
    
    private func calculateReward(currentState: SensorInput, nextState: SensorInput?) -> Double {
        if let nextState {
            let energyDelta = nextState.energy - currentState.energy
            if energyDelta < 0 {
                return energyDelta * 0.5
            } else {
                return energyDelta
            }
        } else {
            return currentState.energy > 0 ? 100 : -100
        }
    }
}
