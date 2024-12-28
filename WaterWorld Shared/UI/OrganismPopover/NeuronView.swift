//
//  NeuronView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/25/24.
//
import SwiftUI

struct NeuronViewModel {
    let weights: [Double]
    let bias: Double
    let output: Double
    let isActive: Bool
}

struct NeuronView: View {
    let neuron: NeuronViewModel

    var body: some View {
        HStack(spacing: 5) {
            // Inputs and Weights
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(zip(neuron.weights, neuron.weights.indices)), id: \.1) { weight, _ in
                    Text("\(String(format: "%.2f", weight))")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                // Bias
                Text("b: \(String(format: "%.2f", neuron.bias))")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            // Activation circle
            Circle()
                .fill(neuron.isActive ? Color.green : Color.gray)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
                .overlay {
                    let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
                    let value = style.format(neuron.output)
                    Text(value)
                }
                .animation(.easeInOut(duration: 0.3), value: neuron.isActive)
        }
    }
}
