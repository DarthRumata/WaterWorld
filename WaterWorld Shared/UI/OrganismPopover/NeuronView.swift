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
    let intensity: Double
}

struct NeuronView: View {
    let neuron: NeuronViewModel

    private var circleBrightness: Double { 0.3 + 0.7 * neuron.intensity }
    private var circleColor: Color { Color(hue: 0.33, saturation: 0.8, brightness: circleBrightness) }
    private var valueTextColor: Color { circleBrightness > 0.6 ? .black : .white }

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
                .fill(circleColor)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
                .overlay {
                    let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
                    let value = style.format(neuron.output)
                    Text(value)
                        .foregroundColor(valueTextColor)
                }
                .animation(.easeInOut(duration: 0.25), value: neuron.intensity)
        }
    }
}
