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

    // Adam first/second moment accumulators — optimizer state, not model state (excluded from snapshot)
    var m: [Double]
    var v: [Double]
    var mBias: Double = 0
    var vBias: Double = 0

    init(weights: [Double], bias: Double) {
        self.weights = weights
        self.bias = bias
        self.m = [Double](repeating: 0, count: weights.count)
        self.v = [Double](repeating: 0, count: weights.count)
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

    mutating func updateWeights(
        learningRate: Double, delta: Double, inputs: [Double],
        step: Int, beta1: Double, beta2: Double, eps: Double, useAdam: Bool
    ) {
        if useAdam {
            let t = Double(step)
            let β1t = pow(beta1, t)
            let β2t = pow(beta2, t)
            for i in weights.indices {
                let g = delta * inputs[i]
                m[i] = beta1 * m[i] + (1 - beta1) * g
                v[i] = beta2 * v[i] + (1 - beta2) * g * g
                let mHat = m[i] / (1 - β1t)
                let vHat = v[i] / (1 - β2t)
                weights[i] -= learningRate * mHat / (sqrt(vHat) + eps)
            }
            mBias = beta1 * mBias + (1 - beta1) * delta
            vBias = beta2 * vBias + (1 - beta2) * delta * delta
            let mHatBias = mBias / (1 - β1t)
            let vHatBias = vBias / (1 - β2t)
            bias -= learningRate * mHatBias / (sqrt(vHatBias) + eps)
        } else {
            for i in weights.indices {
                weights[i] -= learningRate * delta * inputs[i]
            }
            bias -= learningRate * delta
        }
    }
}
