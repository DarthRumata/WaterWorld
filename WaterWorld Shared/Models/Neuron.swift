//
//  Neuron.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Foundation

class Neuron {
    let weights: [Double]
    let bias: Double

    init(weights: [Double], bias: Double) {
        self.weights = weights
        self.bias = bias
    }

    func activate(inputs: [Double]) -> Double {
        if inputs.count != weights.count {
            fatalError("Previous layer neuron count shoud be equal to quantity of weights in each neuron of the next layer")
        }
        
        let weightedSum = zip(weights, inputs).map(*).reduce(0, +) + bias
        return sigmoid(weightedSum)
    }

    private func sigmoid(_ x: Double) -> Double {
        return 1 / (1 + exp(-x))
    }
}
