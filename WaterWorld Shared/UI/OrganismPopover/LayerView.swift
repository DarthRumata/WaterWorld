//
//  LayerView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/25/24.
//

import SwiftUI

struct LayerView: View {
    let neurons: [NeuronViewModel]
    let activation: Activation
    let layerIndex: Int

    private var activationLabel: String {
        switch activation {
        case .relu: return "ReLU"
        case .sigmoid: return "Sigmoid"
        case .softmax: return "Softmax"
        case .linear: return "Linear"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Text("Layer \(layerIndex + 1) • \(activationLabel)")
                .foregroundColor(.white)
                .padding(4)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(6)

            Spacer()

            HStack(alignment: .top, spacing: 10) {
                ForEach(0 ..< neurons.count, id: \.self) { neuronIndex in
                    NeuronView(neuron: neurons[neuronIndex])
                }
            }

            Spacer()
        }
    }
}

