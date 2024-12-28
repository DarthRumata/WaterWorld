//
//  OrganismPopover.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/25/24.
//

import SwiftUI

struct OrganismPopover: View {
    let model: OrganismModel
    let onTapCloseButton: () -> Void

    @State private var neuralNetwork: NeuralNetwork? = nil
    @State private var inputStream: AsyncStream<SensorInput>? = nil
    @State private var name: String? = nil

    var body: some View {
        Group {
            if let neuralNetwork, let inputStream, let name {
                NeuralNetworkView(network: neuralNetwork, inputStream: inputStream, name: name) {
                    onTapCloseButton()
                }
            } else {
                ProgressView("Loading Neural Network...")
            }
        }
        .onAppear {
            Task {
                self.neuralNetwork = await model.neuralNetwork
                self.inputStream = await model.inputsPublisher
                self.name = model.name
            }
        }
    }
}
