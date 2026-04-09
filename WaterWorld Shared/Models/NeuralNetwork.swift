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

extension Activation {
    func derivative(at z: Double) -> Double {
        switch self {
        case .sigmoid:
            let sigmoid = 1.0 / (1.0 + exp(-z))
            return sigmoid * (1 - sigmoid)
        case .relu:
            return z > 0 ? 1.0 : 0.0
        case .softmax, .linear:
            return 1.0
        }
    }
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
    var layers: [NeuralLayer]

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
    
    mutating func backward(error: [Double], inputs: [Double], learningRate: Double) {
        // Cache activations for each layer
        var activations: [[Double]] = [inputs]
        var currentInputs = inputs
        for layer in layers {
            let outputs = layer.computeOutputs(inputs: currentInputs)
            activations.append(outputs)
            currentInputs = outputs
        }
        // Propagate error backwards
        var currentError = error
        for i in (0..<layers.count).reversed() {
            let inputToLayer = activations[i]
            currentError = layers[i].backward(error: currentError, inputs: inputToLayer, learningRate: learningRate)
        }
    }
}

struct NeuralLayer: Sendable {
    var neurons: [Neuron]
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
    
    mutating func backward(error: [Double], inputs: [Double], learningRate: Double) -> [Double] {
        var prevLayerError = [Double](repeating: 0.0, count: neurons[0].weights.count)
        
        for i in neurons.indices {
            var neuron = neurons[i]
            let z = neuron.weightedSum(inputs: inputs)
            
            let activationDeriv = activation.derivative(at: z)
            
            let delta = error[i] * activationDeriv
            
            // Update weights
            neuron.updateWeights(learningRate: learningRate, delta: delta, inputs: inputs)
            neurons[i] = neuron
        }
        
        return prevLayerError
    }
}

