//
//  Neuron.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/14/24.
//

import Accelerate

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
        vDSP.dot(weights, inputs) + bias
    }

    mutating func polyakBlend(toward main: Neuron, tau: Double) {
        weights = vDSP.add(vDSP.multiply(tau, main.weights), vDSP.multiply(1 - tau, weights))
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

            let g = vDSP.multiply(delta, inputs)
            m = vDSP.add(vDSP.multiply(beta1, m), vDSP.multiply(1 - beta1, g))
            v = vDSP.add(vDSP.multiply(beta2, v), vDSP.multiply(1 - beta2, vDSP.multiply(g, g)))

            let mHat = vDSP.multiply(1 / (1 - β1t), m)
            let vHat = vDSP.multiply(1 / (1 - β2t), v)
            let denom = vDSP.add(eps, vForce.sqrt(vHat))
            let update = vDSP.multiply(learningRate, vDSP.divide(mHat, denom))
            weights = vDSP.add(weights, vDSP.multiply(-1.0, update))

            let gBias = delta
            mBias = beta1 * mBias + (1 - beta1) * gBias
            vBias = beta2 * vBias + (1 - beta2) * gBias * gBias
            let mHatBias = mBias / (1 - β1t)
            let vHatBias = vBias / (1 - β2t)
            bias -= learningRate * mHatBias / (sqrt(vHatBias) + eps)
        } else {
            weights = vDSP.add(weights, vDSP.multiply(-(learningRate * delta), inputs))
            bias -= learningRate * delta
        }
    }
}
