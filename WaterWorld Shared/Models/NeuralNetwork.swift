//
//  NeuralNetwork.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Foundation

// MARK: - Learning Health

enum LearningWarning: Sendable, Equatable {
    case dyingReLU(layerIndex: Int, deadRatio: Double)
    case explodingWeights(layerIndex: Int, meanAbsWeight: Double)

    var description: String {
        switch self {
        case let .dyingReLU(layer, ratio):
            return "ReLU L\(layer + 1): \(Int(ratio * 100))% dead"
        case let .explodingWeights(layer, mean):
            return "Weights L\(layer + 1): \(String(format: "%.1f", mean))"
        }
    }
}

// MARK: -

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
    
    /// Runs diagnostics on hidden layers using provided sample inputs.
    /// - Dying ReLU: > 70% of neurons output 0 across all samples.
    /// - Exploding weights: mean |weight| > 10.
    func healthCheck(sampleInputs: [[Double]]) -> [LearningWarning] {
        guard !sampleInputs.isEmpty, layers.count > 1 else { return [] }
        var warnings: [LearningWarning] = []
        let hiddenLayers = layers.dropLast()

        for (layerIndex, layer) in hiddenLayers.enumerated() {
            // Exploding weights check
            let allWeights = layer.neurons.flatMap(\.weights)
            let meanAbsWeight = allWeights.reduce(0.0) { $0 + abs($1) } / Double(max(allWeights.count, 1))
            if meanAbsWeight > 10.0 {
                warnings.append(.explodingWeights(layerIndex: layerIndex, meanAbsWeight: meanAbsWeight))
            }

            // Dying ReLU check
            guard case .relu = layer.activation else { continue }
            var deadCount = 0
            for input in sampleInputs {
                let layerInput = layers[0..<layerIndex].reduce(input) { current, l in l.computeOutputs(inputs: current) }
                deadCount += layer.computeOutputs(inputs: layerInput).filter { $0 == 0 }.count
            }
            let deadRatio = Double(deadCount) / Double(layer.neurons.count * sampleInputs.count)
            if deadRatio > 0.7 {
                warnings.append(.dyingReLU(layerIndex: layerIndex, deadRatio: deadRatio))
            }
        }
        return warnings
    }

    /// Polyak averaging: θ_self = τ·θ_main + (1−τ)·θ_self
    /// Applied per-weight every training step for smooth target tracking.
    mutating func polyakBlend(toward main: NeuralNetwork, tau: Double) {
        for l in layers.indices {
            for n in layers[l].neurons.indices {
                layers[l].neurons[n].polyakBlend(toward: main.layers[l].neurons[n], tau: tau)
            }
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

