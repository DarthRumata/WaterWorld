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
        // Forward pass: cache inputs and pre-activation z values per layer
        struct LayerCache {
            let inputs: [Double]
            let zs: [Double]
        }
        var caches: [LayerCache] = []
        var currentInputs = inputs
        for layer in layers {
            let zs = layer.neurons.map { $0.weightedSum(inputs: currentInputs) }
            let outputs = layer.applyActivation(zs)
            caches.append(LayerCache(inputs: currentInputs, zs: zs))
            currentInputs = outputs
        }
        // Backward pass: reuse cached z values, no redundant computation
        var currentError = error
        for i in (0..<layers.count).reversed() {
            currentError = layers[i].backward(error: currentError, inputs: caches[i].inputs, zs: caches[i].zs, learningRate: learningRate)
        }
    }
}

struct NeuralLayer: Sendable {
    var neurons: [Neuron]
    let activation: Activation

    init(neurons: [Neuron], activation: Activation) {
        self.neurons = neurons
        self.activation = activation
    }

    init(neuronCount: Int, inputCount: Int, weightInitStrategy: InitializationStrategy, activation: Activation) {
        self.activation = activation
        neurons = (0..<neuronCount).map { _ in
            let weights = weightInitStrategy.weights(inputCount: inputCount, outputCount: neuronCount)
            return Neuron(weights: weights, bias: 0)
        }
    }

    // Forward pass for the layer
    func computeOutputs(inputs: [Double]) -> [Double] {
        applyActivation(neurons.map { $0.weightedSum(inputs: inputs) })
    }

    func applyActivation(_ zs: [Double]) -> [Double] {
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

    mutating func backward(error: [Double], inputs: [Double], zs: [Double], learningRate: Double) -> [Double] {
        var prevLayerError = [Double](repeating: 0.0, count: neurons[0].weights.count)
        for i in neurons.indices {
            let delta = error[i] * activation.derivative(at: zs[i])
            for j in neurons[i].weights.indices {
                prevLayerError[j] += neurons[i].weights[j] * delta
            }
            neurons[i].updateWeights(learningRate: learningRate, delta: delta, inputs: inputs)
        }
        return prevLayerError
    }
}

