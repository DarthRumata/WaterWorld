//
//  NeuralNetwork.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Foundation

enum Activation: Sendable {
    case sigmoid
    case relu
    case softmax
    case linear
}

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

        // Create hidden layers (default activation: sigmoid)
        for size in hiddenLayerSizes {
            allLayers.append(
                NeuralLayer(
                    neuronCount: size,
                    inputCount: previousSize,
                    weightInitStrategy: weightInitStrategy,
                    activation: .sigmoid
                )
            )
            previousSize = size
        }

        // Create output layer (default activation: sigmoid)
        allLayers.append(
            NeuralLayer(
                neuronCount: outputSize,
                inputCount: previousSize,
                weightInitStrategy: weightInitStrategy,
                activation: .sigmoid
            )
        )
        
        layers = allLayers
    }

    init(layers: [NeuralLayer]) {
        self.layers = layers
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
    let activation: Activation

    init(neuronCount: Int, inputCount: Int, weightInitStrategy: InitializationStrategy, activation: Activation) {
        self.activation = activation
        neurons = (0..<neuronCount).map { _ in
            let weights = weightInitStrategy.weights(inputCount: inputCount, outputCount: neuronCount)
            return Neuron(weights: weights, bias: 0)
        }
    }

    // Forward pass for the layer
    func computeOutputs(inputs: [Double]) -> [Double] {
        let zs = neurons.map { $0.weightedSum(inputs: inputs) }
        switch activation {
        case .sigmoid:
            return zs.map { 1.0 / (1.0 + exp(-$0)) }
        case .relu:
            return zs.map { max(0.0, $0) }
        case .softmax:
            let maxZ = zs.max() ?? 0.0
            let exps = zs.map { exp($0 - maxZ) }
            let sumExp = exps.reduce(0.0, +)
            return exps.map { $0 / (sumExp == 0 ? 1 : sumExp) }
        case .linear:
            return zs
        }
    }
}
