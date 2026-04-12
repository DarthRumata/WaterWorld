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
    let isOutputNeuron: Bool
}

struct NeuronView: View {
    let neuron: NeuronViewModel

    @State private var isHovered = false

    private var circleColor: Color {
        if neuron.isOutputNeuron {
            return neuron.isActive
                ? Color(hue: 0.33, saturation: 0.9, brightness: 0.9)  // winner: green
                : Color(white: 0.2)                                     // others: dark gray
        }
        let brightness = 0.3 + 0.7 * neuron.intensity
        return Color(hue: 0.33, saturation: 0.8, brightness: brightness)
    }
    private var valueTextColor: Color {
        neuron.isOutputNeuron
            ? (neuron.isActive ? .black : .gray)
            : ((0.3 + 0.7 * neuron.intensity) > 0.6 ? .black : .white)
    }

    var body: some View {
        Circle()
            .fill(circleColor)
            .frame(width: 30, height: 30)
            .overlay(Circle().stroke(Color.white, lineWidth: 1))
            .overlay {
                Text(String(format: "%.2f", neuron.output))
                    .font(.system(size: 8, weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(valueTextColor)
                    .padding(2)
            }
            .overlay(alignment: .bottom) {
                if isHovered {
                    WeightsTooltip(weights: neuron.weights, bias: neuron.bias)
                        .offset(y: 36)
                        .zIndex(10)
                }
            }
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.25), value: neuron.intensity)
    }
}

private struct WeightsTooltip: View {
    let weights: [Double]
    let bias: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(weights.indices, id: \.self) { i in
                Text("w\(i): \(String(format: "%+.3f", weights[i]))")
            }
            Divider().background(Color.white.opacity(0.3))
            Text("bias: \(String(format: "%+.3f", bias))")
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .fixedSize()
    }
}
