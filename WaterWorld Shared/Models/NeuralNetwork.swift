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
        case .linear:
            return 1.0
        case .softmax:
            // Softmax Jacobian is non-diagonal — use NeuralLayer.computeDeltas instead.
            fatalError("derivative(at:) must not be called for softmax")
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
    var adamStep: Int = 0

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
    /// - Dying ReLU: a neuron is dead only if it outputs 0 on ALL samples (not just sometimes).
    ///   Reports warning when > 70% of neurons in a ReLU layer are truly dead.
    /// - Exploding weights: mean |weight| > 10.
    /// Single linear O(N) pass per sample — no redundant recomputation of earlier layers.
    func healthCheck(sampleInputs: [[Double]]) -> [LearningWarning] {
        guard !sampleInputs.isEmpty, layers.count > 1 else { return [] }
        let hiddenLayers = Array(layers.dropLast())

        // zeroCount[layerIndex][neuronIndex] = how many samples produced 0 for this neuron
        var zeroCount = hiddenLayers.map { Array(repeating: 0, count: $0.neurons.count) }

        for input in sampleInputs {
            var current = input
            for (i, layer) in hiddenLayers.enumerated() {
                let outputs = layer.computeOutputs(inputs: current)
                for (j, output) in outputs.enumerated() where output == 0 {
                    zeroCount[i][j] += 1
                }
                current = outputs
            }
        }

        var warnings: [LearningWarning] = []
        for (i, layer) in hiddenLayers.enumerated() {
            // Exploding weights check
            let allWeights = layer.neurons.flatMap(\.weights)
            let meanAbsWeight = allWeights.reduce(0.0) { $0 + abs($1) } / Double(max(allWeights.count, 1))
            if meanAbsWeight > 10.0 {
                warnings.append(.explodingWeights(layerIndex: i, meanAbsWeight: meanAbsWeight))
            }

            // Dead neuron check: neuron is dead only if zero on ALL samples
            guard case .relu = layer.activation else { continue }
            let deadNeurons = zeroCount[i].filter { $0 == sampleInputs.count }.count
            let deadRatio = Double(deadNeurons) / Double(layer.neurons.count)
            if deadRatio > 0.7 {
                warnings.append(.dyingReLU(layerIndex: i, deadRatio: deadRatio))
            }
        }
        return warnings
    }

    /// Polyak averaging: θ_self = τ·θ_main + (1−τ)·θ_self
    /// Applied per-weight every training step for smooth target tracking.
    mutating func resetAdamState() {
        adamStep = 0
        for l in layers.indices {
            for n in layers[l].neurons.indices {
                layers[l].neurons[n].m = [Double](repeating: 0, count: layers[l].neurons[n].m.count)
                layers[l].neurons[n].v = [Double](repeating: 0, count: layers[l].neurons[n].v.count)
                layers[l].neurons[n].mBias = 0
                layers[l].neurons[n].vBias = 0
            }
        }
    }

    /// Divergence of this network from `main` as a percentage of main's weight scale:
    /// (mean |θ_self - θ_main|) / (mean |θ_main|) * 100.
    /// Call on the target network before polyakBlend to see accumulated drift.
    func weightDivergencePercent(from main: NeuralNetwork) -> Double {
        var diffSum = 0.0
        var mainAbsSum = 0.0
        for (l, layer) in layers.enumerated() {
            for (n, neuron) in layer.neurons.enumerated() {
                let mainNeuron = main.layers[l].neurons[n]
                for (j, w) in neuron.weights.enumerated() {
                    diffSum += abs(w - mainNeuron.weights[j])
                    mainAbsSum += abs(mainNeuron.weights[j])
                }
                diffSum += abs(neuron.bias - mainNeuron.bias)
                mainAbsSum += abs(mainNeuron.bias)
            }
        }
        guard mainAbsSum > 0 else { return 0 }
        return diffSum / mainAbsSum * 100
    }

    /// Mean actual weight step: α · mean(|m̂ᵢ| / (√v̂ᵢ + ε)), bias-corrected.
    /// Range [0, alpha]. High = gradients consistent, network learning fast. Low = gradients noisy, network stalling.
    func meanWeightStep(alpha: Double, beta1: Double, beta2: Double, eps: Double) -> Double {
        guard adamStep > 0 else { return 0 }
        let bc1 = 1.0 - pow(beta1, Double(adamStep))
        let bc2 = 1.0 - pow(beta2, Double(adamStep))
        var sum = 0.0
        var count = 0
        for layer in layers {
            for neuron in layer.neurons {
                for i in neuron.m.indices {
                    let mHat = neuron.m[i] / bc1
                    let vHat = max(0, neuron.v[i] / bc2)
                    sum += abs(mHat) / (sqrt(vHat) + eps)
                    count += 1
                }
                let mHatBias = neuron.mBias / bc1
                let vHatBias = max(0, neuron.vBias / bc2)
                sum += abs(mHatBias) / (sqrt(vHatBias) + eps)
                count += 1
            }
        }
        return count > 0 ? alpha * sum / Double(count) : 0
    }

    mutating func polyakBlend(toward main: NeuralNetwork, tau: Double) {
        for l in layers.indices {
            for n in layers[l].neurons.indices {
                layers[l].neurons[n].polyakBlend(toward: main.layers[l].neurons[n], tau: tau)
            }
        }
    }

    mutating func backward(error: [Double], inputs: [Double], learningRate: Double, beta1: Double, beta2: Double, eps: Double, useAdam: Bool) {
        adamStep += 1
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
            currentError = layers[i].backward(error: currentError, inputs: caches[i].inputs, zs: caches[i].zs, learningRate: learningRate, step: adamStep, beta1: beta1, beta2: beta2, eps: eps, useAdam: useAdam)
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

    mutating func backward(error: [Double], inputs: [Double], zs: [Double], learningRate: Double, step: Int, beta1: Double, beta2: Double, eps: Double, useAdam: Bool) -> [Double] {
        let deltas = computeDeltas(error: error, zs: zs)
        var prevLayerError = [Double](repeating: 0.0, count: neurons[0].weights.count)
        for i in neurons.indices {
            for j in neurons[i].weights.indices {
                prevLayerError[j] += neurons[i].weights[j] * deltas[i]
            }
            neurons[i].updateWeights(learningRate: learningRate, delta: deltas[i], inputs: inputs, step: step, beta1: beta1, beta2: beta2, eps: eps, useAdam: useAdam)
        }
        return prevLayerError
    }

    /// Computes per-neuron deltas (∂L/∂z) for all activations.
    /// Softmax requires the full Jacobian-vector product and cannot be handled elementwise.
    private func computeDeltas(error: [Double], zs: [Double]) -> [Double] {
        switch activation {
        case .softmax:
            // s = softmax(z)
            let maxZ = zs.max() ?? 0
            let exps = zs.map { exp($0 - maxZ) }
            let sumExp = exps.reduce(0.0, +)
            let s = exps.map { $0 / sumExp }
            // Jacobian-vector product: ∂L/∂z_i = s_i * (e_i − Σ_j e_j·s_j)
            let dot = zip(error, s).reduce(0.0) { $0 + $1.0 * $1.1 }
            return zip(s, error).map { si, ei in si * (ei - dot) }
        default:
            // All other activations have diagonal Jacobians — elementwise multiply is correct.
            return zip(error, zs).map { ei, zi in ei * activation.derivative(at: zi) }
        }
    }
}

