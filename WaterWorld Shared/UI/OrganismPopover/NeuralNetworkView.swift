//
//  NeuralNetworkView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/24/24.
//

import SwiftUI

struct NeuralNetworkViewModel {
    let inputs: SensorInput
    let layers: [NeuralLayerViewModel]
}

struct NeuralLayerViewModel {
    let neurons: [NeuronViewModel]
    let activation: Activation
}

struct NeuralNetworkView: View {
    let network: NeuralNetwork
    let inputStream: AsyncStream<SensorInput>
    let name: String
    let onTapCloseButton: () -> Void

    @State private var viewModel: NeuralNetworkViewModel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack {
                    Text(name)
                }
                .frame(maxWidth: .infinity)
                
                CloseButton {
                    onTapCloseButton()
                }
            }

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 25) {
                    if let viewModel {
                        InputsView(inputs: viewModel.inputs)

                        ForEach(Array(zip(viewModel.layers, viewModel.layers.indices)), id: \.1) { layer, layerIndex in
                            LayerView(neurons: layer.neurons, activation: layer.activation, layerIndex: layerIndex)
                        }

                        HStack(spacing: 10) {
                            Spacer() // Add space before the labels start
                                .frame(width: 70) // Align with the Layer label

                            Text("Up")
                                .frame(width: 70)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)

                            Text("Down")
                                .frame(width: 70)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)

                            Text("Wait")
                                .frame(width: 70)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 50)
                    }
                }
                .padding(15)
            }
            .background(Color.black.opacity(0.8))
        }
        .task {
            await readFromStream()
        }
    }

    // Read from AsyncStream
    private func readFromStream() async {
        if viewModel == nil {
            let initial = SensorInput(lightLevel: 0, depth: 0, dayProgress: 0, energy: 0)
            viewModel = generateViewModel(for: initial)
        }
        for await input in inputStream {
            viewModel = generateViewModel(for: input)
        }
    }

    private func generateViewModel(for input: SensorInput) -> NeuralNetworkViewModel {
        var inputs = input.normalized
        var layerViewModels = [NeuralLayerViewModel]()

        for (index, layer) in network.layers.enumerated() {
            let isOutputLayer = index == network.layers.count - 1
            let activation = layer.activation
            let outputs = layer.computeOutputs(inputs: inputs)
            let neurons = createNeuronViewModels(for: layer, outputs: outputs, activation: activation, isOutputLayer: isOutputLayer)
            let layerViewModel = NeuralLayerViewModel(neurons: neurons, activation: activation)
            layerViewModels.append(layerViewModel)
            inputs = neurons.map { $0.output }
        }

        return NeuralNetworkViewModel(inputs: input, layers: layerViewModels)
    }

    private func createNeuronViewModels(for layer: NeuralLayer, outputs: [Double], activation: Activation, isOutputLayer: Bool) -> [NeuronViewModel] {
        let maxOutputIndex = outputs.indices.max(by: { outputs[$0] < outputs[$1] })
        let hiddenSoftmaxThreshold = 1.0 / Double(max(outputs.count, 1))
        return zip(layer.neurons, outputs).enumerated().map { index, neuronAndOutput in
            let (neuron, output) = neuronAndOutput

            // Determine isActive depending on layer role and activation
            let isActive: Bool
            if isOutputLayer {
                // Highlight the argmax for outputs (works well for softmax too)
                isActive = index == maxOutputIndex
            } else {
                switch activation {
                case .relu:
                    isActive = output > 0.0
                case .sigmoid:
                    isActive = output > 0.5
                case .softmax:
                    isActive = output > hiddenSoftmaxThreshold
                case .linear:
                    isActive = output > 0.0
                }
            }

            // Compute an intensity in 0...1 for visualization
            let intensity: Double
            switch activation {
            case .sigmoid:
                intensity = max(0.0, min(1.0, output))
            case .relu:
                intensity = max(0.0, min(1.0, output))
            case .softmax:
                intensity = max(0.0, min(1.0, output))
            case .linear:
                intensity = max(0.0, min(1.0, output))
            }

            return NeuronViewModel(
                weights: neuron.weights,
                bias: neuron.bias,
                output: output,
                isActive: isActive,
                intensity: intensity
            )
        }
    }
}

struct InputsView: View {
    let inputs: SensorInput

    var body: some View {
        HStack(spacing: 10) {
            ForEach(inputDetails, id: \.0) { label, value in
                HStack(spacing: 2) {
                    Text(label)
                        .bold()
                        .foregroundColor(.white)
                    Text(value)
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var inputDetails: [(String, String)] {
        [
            ("Depth:", inputs.depth.formatted(.number.precision(.significantDigits(2)))),
            ("Light:", inputs.lightLevel.formatted(.number.precision(.significantDigits(2)))),
            ("Energy:", inputs.energy.formatted(.number.precision(.significantDigits(2)))),
            ("Time:", inputs.dayProgress.formatted(.number.precision(.significantDigits(2))))
        ]
    }
}

struct CloseButton: View {
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.white)
                .padding(5)
        }
    }
}
