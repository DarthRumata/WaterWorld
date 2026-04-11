//
//  NeuralNetworkSnapshot.swift
//  WaterWorld Shared
//

import Foundation

struct NeuralNetworkSnapshot: Codable {
    struct LayerSnapshot: Codable {
        let weights: [[Double]]  // [neuronIndex][weightIndex]
        let biases: [Double]
        let activation: String
    }
    let layers: [LayerSnapshot]
}

extension NeuralNetwork {
    func makeSnapshot() -> NeuralNetworkSnapshot {
        let layerSnapshots = layers.map { layer in
            NeuralNetworkSnapshot.LayerSnapshot(
                weights: layer.neurons.map { $0.weights },
                biases: layer.neurons.map { $0.bias },
                activation: "\(layer.activation)"
            )
        }
        return NeuralNetworkSnapshot(layers: layerSnapshots)
    }

    init?(snapshot: NeuralNetworkSnapshot) {
        let restoredLayers = snapshot.layers.compactMap { layerSnap -> NeuralLayer? in
            guard !layerSnap.weights.isEmpty,
                  layerSnap.weights.count == layerSnap.biases.count else { return nil }
            let activation: Activation
            switch layerSnap.activation {
            case "sigmoid": activation = .sigmoid
            case "relu":    activation = .relu
            case "softmax": activation = .softmax
            case "linear":  activation = .linear
            default: return nil
            }
            let neurons = zip(layerSnap.weights, layerSnap.biases).map {
                Neuron(weights: $0.0, bias: $0.1)
            }
            return NeuralLayer(neurons: neurons, activation: activation)
        }
        guard restoredLayers.count == snapshot.layers.count else { return nil }
        self.init(layers: restoredLayers)
    }
}

extension NeuralNetworkSnapshot {
    static let defaultFileName = "neural_network.json"

    static func save(_ snapshot: NeuralNetworkSnapshot, to url: URL) throws {
        try JSONEncoder().encode(snapshot).write(to: url)
    }

    static func load(from url: URL) throws -> NeuralNetworkSnapshot {
        try JSONDecoder().decode(NeuralNetworkSnapshot.self, from: Data(contentsOf: url))
    }

    static func save(_ snapshot: NeuralNetworkSnapshot, named fileName: String = defaultFileName) throws {
        try save(snapshot, to: storageURL(for: fileName))
    }

    static func load(named fileName: String = defaultFileName) throws -> NeuralNetworkSnapshot {
        try load(from: storageURL(for: fileName))
    }

    static func storageURL(for fileName: String) throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }
}
