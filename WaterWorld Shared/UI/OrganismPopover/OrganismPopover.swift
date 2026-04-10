//
//  OrganismPopover.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/25/24.
//

import SwiftUI

struct OrganismPopover: View {
    let model: OrganismModel
    let network: NeuralNetwork
    let onTapCloseButton: () -> Void

    @State private var inputStream: AsyncStream<SensorInput>?

    var body: some View {
        Group {
            if let inputStream {
                NeuralNetworkView(network: network, inputStream: inputStream, name: model.name) {
                    onTapCloseButton()
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            Task {
                self.inputStream = await model.inputsPublisher
            }
        }
    }
}
