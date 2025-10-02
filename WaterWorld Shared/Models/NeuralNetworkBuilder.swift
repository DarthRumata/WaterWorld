import Foundation

struct LayerTemplate: Sendable {
    enum Kind: Sendable { case dense }
    let kind: Kind
    let units: Int
    let activation: Activation

    init(kind: Kind, units: Int, activation: Activation) {
        self.kind = kind
        self.units = units
        self.activation = activation
    }

    // Convenience factory for dense layers
    static func dense(_ units: Int, activation: Activation = .sigmoid) -> LayerTemplate {
        LayerTemplate(kind: .dense, units: units, activation: activation)
    }
}

struct NeuralNetworkBuilder: Sendable {
    private let inputSize: Int
    private var templates: [LayerTemplate] = []

    init(inputSize: Int) {
        self.inputSize = inputSize
    }

    // Chainable API to add a dense layer
    func dense(_ units: Int, activation: Activation = .sigmoid) -> NeuralNetworkBuilder {
        var copy = self
        copy.templates.append(LayerTemplate.dense(units, activation: activation))
        return copy
    }

    // Add a generic template (future extensibility)
    func add(_ template: LayerTemplate) -> NeuralNetworkBuilder {
        var copy = self
        copy.templates.append(template)
        return copy
    }

    // Build the network using the provided initialization strategy (default preserves existing behavior)
    func build(weightInitStrategy: InitializationStrategy = .uniformXavier) -> NeuralNetwork {
        var previousSize = inputSize
        var builtLayers: [NeuralLayer] = []

        for template in templates {
            switch template.kind {
            case .dense:
                builtLayers.append(
                    NeuralLayer(
                        neuronCount: template.units,
                        inputCount: previousSize,
                        weightInitStrategy: weightInitStrategy,
                        activation: template.activation
                    )
                )
                previousSize = template.units
            }
        }

        return NeuralNetwork(layers: builtLayers)
    }
}

extension NeuralNetwork {
    static func build(
        inputSize: Int,
        templates: [LayerTemplate],
        weightInitStrategy: InitializationStrategy = .uniformXavier
    ) -> NeuralNetwork {
        var previousSize = inputSize
        var builtLayers: [NeuralLayer] = []
        for template in templates {
            switch template.kind {
            case .dense:
                builtLayers.append(
                    NeuralLayer(
                        neuronCount: template.units,
                        inputCount: previousSize,
                        weightInitStrategy: weightInitStrategy,
                        activation: template.activation
                    )
                )
                previousSize = template.units
            }
        }
        return NeuralNetwork(layers: builtLayers)
    }
}
