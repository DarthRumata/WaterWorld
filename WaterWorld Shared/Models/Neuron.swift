//
//  Neuron.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Foundation

struct Neuron: Sendable {
    private(set) var weights: [Double]
    private(set) var bias: Double

    init(weights: [Double], bias: Double) {
        self.weights = weights
        self.bias = bias
    }

    func weightedSum(inputs: [Double]) -> Double {
        if inputs.count != weights.count {
            fatalError("Previous layer neuron count shoud be equal to quantity of weights in each neuron of the next layer")
        }
        
        return zip(weights, inputs).map(*).reduce(0, +) + bias
    }
    
    mutating func polyakBlend(toward main: Neuron, tau: Double) {
        for i in weights.indices {
            weights[i] = tau * main.weights[i] + (1 - tau) * weights[i]
        }
        bias = tau * main.bias + (1 - tau) * bias
    }

    mutating func updateWeights(learningRate: Double, delta: Double, inputs: [Double]) {
        for i in weights.indices {
            weights[i] -= learningRate * delta * inputs[i]
        }
        
        bias -= learningRate * delta
    }
}
