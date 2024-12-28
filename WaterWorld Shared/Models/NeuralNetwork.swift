//
//  NeuralNetwork.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Foundation

enum InitializationStrategy {
    case uniformXavier
    case uniform
    
    func weights(inputCount: Int, outputCount: Int) -> [Double] {
        let maxDeviation: Double
        
        switch self {
        case .uniformXavier:
            maxDeviation = sqrt(6 / (Double(inputCount) + Double(outputCount)))
        case .uniform:
            maxDeviation = 1
        }
        
        return (0..<inputCount).map { _ in Double.random(in: -maxDeviation...maxDeviation) }
    }
}

struct NeuralNetwork: Sendable {
    let layers: [NeuralLayer]

    init(inputSize: Int, hiddenLayerSizes: [Int], outputSize: Int, weightInitStrategy: InitializationStrategy) {
        var previousSize = inputSize
        var allLayers: [NeuralLayer] = []

        // Create hidden layers
        for size in hiddenLayerSizes {
            allLayers.append(
                NeuralLayer(
                    neuronCount: size,
                    inputCount: previousSize,
                    weightInitStrategy: weightInitStrategy
                )
            )
            previousSize = size
        }

        // Create output layer
        allLayers.append(
            NeuralLayer(
                neuronCount: outputSize,
                inputCount: previousSize,
                weightInitStrategy: weightInitStrategy
            )
        )
        
        layers = allLayers
    }

    // Forward pass for the network
    func predict(inputs: [Double]) -> [Double] {
        return layers.reduce(inputs) { currentInputs, layer in
            layer.computeOutputs(inputs: currentInputs)
        }
    }
}

struct NeuralLayer: Sendable {
    let neurons: [Neuron]

    init(neuronCount: Int, inputCount: Int, weightInitStrategy: InitializationStrategy) {
        neurons = (0..<neuronCount).map { _ in
            // Create each neuron with random weights and biases
            let weights = weightInitStrategy.weights(inputCount: inputCount, outputCount: neuronCount)
            return Neuron(weights: weights, bias: 0)
        }
    }

    // Forward pass for the layer
    func computeOutputs(inputs: [Double]) -> [Double] {
        neurons.map { $0.activate(inputs: inputs) }
    }
}
