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
    let network = NeuralNetwork(
        inputSize: 4,
        hiddenLayerSizes: [4],
        outputSize: 3,
        weightInitStrategy: .uniformXavier
    )
    
    func calculateResponse(on input: SensorInput) async -> OrganismModel.Action {
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
