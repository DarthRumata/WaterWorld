//
//  NeuralBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

actor NeuralBrain: BrainProtocol {
    var neuralNetwork: NeuralNetwork? {
        network
    }
    let network = NeuralNetworkBuilder(inputSize: 4)
        .dense(4, activation: .relu)
        .dense(3, activation: .softmax)
        .build(weightInitStrategy: .uniformXavier)
    
    func calculateResponse(on input: OrganismState) async -> OrganismModel.Action {
        let inputs = input.normalized
        let actionStimuli = network.predict(inputs: inputs)
        
        var bestStimulusIndex = 0
        var maxStimulus = Double.leastNormalMagnitude
        for (i, stimulus) in actionStimuli.enumerated() {
            if stimulus > maxStimulus {
                maxStimulus = stimulus
                bestStimulusIndex = i
            }
        }
        
        return OrganismModel.Action.allCases[bestStimulusIndex]
    }
}
