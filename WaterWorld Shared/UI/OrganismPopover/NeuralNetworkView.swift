//
//  NeuralNetworkView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/24/24.
//

import SwiftUI
import Foundation

#if os(OSX)
import AppKit
#endif

struct NeuralNetworkViewModel {
    let inputs: OrganismState
    let layers: [NeuralLayerViewModel]
}

struct NeuralLayerViewModel {
    let neurons: [NeuronViewModel]
    let activation: Activation
}

struct NeuralNetworkView: View {
    let network: NeuralNetwork
    let inputStream: AsyncStream<OrganismState>
    let name: String
    let onTapCloseButton: () -> Void

    @State private var viewModel: NeuralNetworkViewModel? = nil
    @State private var contentSize: CGSize = .zero
    @State private var lastUIUpdate: TimeInterval = 0
    private let minUIUpdateInterval: TimeInterval = 0.25

    // Computed layout constraints based on screen and measured content
    private var screenSize: CGSize {
#if os(OSX)
        return NSScreen.main?.visibleFrame.size ?? CGSize(width: 1024, height: 768)
#else
        return CGSize(width: 1024, height: 768)
#endif
    }
    private var maxWidth: CGFloat { screenSize.width * 2.0 / 3.0 }
    private var maxHeight: CGFloat { screenSize.height * 2.0 / 3.0 }
    private var constrainedWidth: CGFloat? {
        contentSize.width > 0 ? min(max(0, contentSize.width), maxWidth) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(name)
                    .font(.title3).bold()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)

                CloseButton {
                    onTapCloseButton()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: constrainedWidth)

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 25) {
                    if let viewModel {
                        InputsView(inputs: viewModel.inputs)

                        ForEach(Array(zip(viewModel.layers, viewModel.layers.indices)), id: \.1) { layer, layerIndex in
                            LayerView(neurons: layer.neurons, activation: layer.activation, layerIndex: layerIndex)
                        }

                        HStack(alignment: .top, spacing: 5) {
                            // Invisible placeholder matching LayerView label width
                            Text("Layer 3 • Linear")
                                .padding(4)
                                .opacity(0)
                            Spacer()
                            HStack(spacing: 10) {
                                ForEach(["Up", "Down", "Wait"], id: \.self) { label in
                                    Text(label)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                        .frame(width: 40)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(15)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: proxy.size)
                    }
                )
            }
            .onPreferenceChange(SizePreferenceKey.self) { newSize in
                self.contentSize = newSize
            }
            .frame(
                width: constrainedWidth,
                height: min(max(0, contentSize.height), maxHeight)
            )
            .background(Color.black.opacity(0.8))
        }
        .task {
            await readFromStream()
        }
    }

    // Read from AsyncStream
    private func readFromStream() async {
        for await input in inputStream {
            let now = Date.timeIntervalSinceReferenceDate
            if viewModel == nil || now - lastUIUpdate >= minUIUpdateInterval {
                viewModel = generateViewModel(for: input)
                lastUIUpdate = now
            }
        }
    }

    private func generateViewModel(for input: OrganismState) -> NeuralNetworkViewModel {
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
        // Normalize ReLU intensity relative to the layer's own max — so the most
        // active neuron is always full brightness and others are shown relatively.
        let reluLayerMax = activation == .relu ? (outputs.max() ?? 0.0) : 0.0

        return zip(layer.neurons, outputs).enumerated().map { index, neuronAndOutput in
            let (neuron, output) = neuronAndOutput

            let isActive: Bool
            if isOutputLayer {
                isActive = index == maxOutputIndex
            } else {
                switch activation {
                case .relu:    isActive = output > 0.0
                case .sigmoid: isActive = output > 0.5
                case .softmax: isActive = output > hiddenSoftmaxThreshold
                case .linear:  isActive = output > 0.0
                }
            }

            let intensity: Double
            switch activation {
            case .relu:
                intensity = reluLayerMax > 0 ? output / reluLayerMax : 0.0
            case .sigmoid, .softmax:
                intensity = max(0.0, min(1.0, output))
            case .linear:
                intensity = 0.0  // output layer uses isActive for color, not intensity
            }

            return NeuronViewModel(
                weights: neuron.weights,
                bias: neuron.bias,
                output: output,
                isActive: isActive,
                intensity: intensity,
                isOutputNeuron: isOutputLayer
            )
        }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct InputsView: View {
    let inputs: OrganismState

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
