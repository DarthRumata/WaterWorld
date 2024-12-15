//
//  NeuralNetwork.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

class NeuralNetwork {
    let layers: [NeuralLayer]

    init(inputSize: Int, hiddenLayerSizes: [Int], outputSize: Int, weightRange: ClosedRange<Double>, biasRange: ClosedRange<Double>) {
        var previousSize = inputSize
        var allLayers: [NeuralLayer] = []

        // Create hidden layers
        for size in hiddenLayerSizes {
            allLayers.append(
                NeuralLayer(
                    neuronCount: size,
                    inputCount: previousSize,
                    weightRange: weightRange,
                    biasRange: biasRange
                )
            )
            previousSize = size
        }

        // Create output layer
        allLayers.append(
            NeuralLayer(
                neuronCount: outputSize,
                inputCount: previousSize,
                weightRange: weightRange,
                biasRange: biasRange
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

class NeuralLayer {
    let neurons: [Neuron]

    init(neuronCount: Int, inputCount: Int, weightRange: ClosedRange<Double>, biasRange: ClosedRange<Double>) {
        neurons = (0..<neuronCount).map { _ in
            // Create each neuron with random weights and biases
            let weights = (0..<inputCount).map { _ in Double.random(in: weightRange) }
            let bias = Double.random(in: biasRange)
            return Neuron(weights: weights, bias: bias)
        }
    }

    // Forward pass for the layer
    func computeOutputs(inputs: [Double]) -> [Double] {
        neurons.map { $0.activate(inputs: inputs) }
    }
}
