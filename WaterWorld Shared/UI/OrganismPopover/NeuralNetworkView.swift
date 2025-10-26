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
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                CloseButton {
                    onTapCloseButton()
                }
            }
            .frame(width: constrainedWidth)

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 25) {
                    if let viewModel {
                        InputsView(inputs: viewModel.inputs)

                        ForEach(Array(zip(viewModel.layers, viewModel.layers.indices)), id: \.1) { layer, layerIndex in
                            LayerView(neurons: layer.neurons, activation: layer.activation, layerIndex: layerIndex)
                        }

                        HStack(spacing: 10) {
                            Spacer().frame(width: 70)
                            Text("Up").frame(width: 70).multilineTextAlignment(.center).foregroundColor(.white)
                            Text("Down").frame(width: 70).multilineTextAlignment(.center).foregroundColor(.white)
                            Text("Wait").frame(width: 70).multilineTextAlignment(.center).foregroundColor(.white)
                        }
                        .padding(.leading, 50)
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
        if viewModel == nil {
            let initial = SensorInput(lightLevel: 0, depth: 0, dayProgress: 0, energy: 0)
            viewModel = generateViewModel(for: initial)
            lastUIUpdate = Date.timeIntervalSinceReferenceDate
        }
        for await input in inputStream {
            let now = Date.timeIntervalSinceReferenceDate
            if now - lastUIUpdate >= minUIUpdateInterval {
                viewModel = generateViewModel(for: input)
                lastUIUpdate = now
            }
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

private struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
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
