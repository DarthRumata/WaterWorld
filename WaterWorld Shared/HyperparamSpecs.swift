struct HyperparamSpec {
    let defaultValue: Double
    let minValue: Double
    let maxValue: Double
    let step: Double
    let format: String

    func clamped(_ value: Double) -> Double {
        Swift.min(maxValue, Swift.max(minValue, value))
    }
}

enum HyperparamSpecs {
    static let gamma        = HyperparamSpec(defaultValue: 0.99,   minValue: 0.1,     maxValue: 0.999,   step: 0.01,  format: "%.3f")
    static let tau          = HyperparamSpec(defaultValue: 0.001,  minValue: 0.0001,  maxValue: 0.01,    step: 0.001, format: "%.4f")
    static let learningRate = HyperparamSpec(defaultValue: 0.001,  minValue: 0.00001, maxValue: 0.1,     step: 0.001, format: "%.5f")
    static let epsilon       = HyperparamSpec(defaultValue: 1.0,    minValue: 0.04,    maxValue: 1.0,     step: 0.05,  format: "%.2f")
    static let epsilonDecay  = HyperparamSpec(defaultValue: 0.995,  minValue: 0.99,    maxValue: 0.9999,  step: 0.001, format: "%.4f")
    static let nStep        = HyperparamSpec(defaultValue: 1,      minValue: 1,       maxValue: 20,      step: 1,     format: "%.0f")
    static let adamBeta1    = HyperparamSpec(defaultValue: 0.9,    minValue: 0.8,     maxValue: 0.999,   step: 0.01,  format: "%.3f")
    static let adamBeta2    = HyperparamSpec(defaultValue: 0.99,   minValue: 0.9,     maxValue: 0.9999,  step: 0.01,  format: "%.4f")
    static let adamEps      = HyperparamSpec(defaultValue: 1e-8,   minValue: 1e-10,   maxValue: 1e-4,    step: 1e-8,  format: "%.2e")
}
