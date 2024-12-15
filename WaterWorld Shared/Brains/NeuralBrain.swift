//
//  NeuralBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

actor NeuralBrain: BrainProtocol {
    let neuralNetwork = NeuralNetwork(
        inputSize: 4,
        hiddenLayerSizes: [4],
        outputSize: 3,
        weightRange: -1...1,
        biasRange: -1...1
    )
    
    func calculateResponse(on input: SensorInput) async -> OrganismModel.Action {
        let inputs = [
            input.lightLevel / GlobalConstants.maxLightLevel,
            input.depth / GlobalConstants.maxDepth,
            input.energy / GlobalConstants.maxEnergy,
            input.dayProgress
        ]
        let actionStimuli = neuralNetwork.predict(inputs: inputs)
        
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
