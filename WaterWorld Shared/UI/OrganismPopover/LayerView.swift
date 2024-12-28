//
//  LayerView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/25/24.
//

import SwiftUI

struct LayerView: View {
    let neurons: [NeuronViewModel]
    let layerIndex: Int

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Text("Layer \(layerIndex + 1)")
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
