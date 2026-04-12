
// MARK: - CostFunctionType

enum CostFunctionType: String, CaseIterable {
    case mse = "MSE"
    case huber = "Huber"

    func make() -> any CostFunction {
        switch self {
        case .mse:   return MSECostFunction()
        case .huber: return HuberCostFunction(delta: 1.0)
        }
    }
}

// MARK: - Protocol

/// A strategy for computing loss and its gradient used during Q-learning.
///
/// - `loss` is the scalar value used for monitoring/reporting.
/// - `gradient` is the per-sample error signal passed to `backward()`.
protocol CostFunction: Sendable {
    /// Scalar loss over a batch — used for monitoring only.
    func loss(predictions: [Double], targets: [Double]) -> Double

    /// Per-sample gradient: ∂L/∂prediction for a single (prediction, target) pair.
    func gradient(prediction: Double, target: Double) -> Double
}

// MARK: - MSE

struct MSECostFunction: CostFunction {
    func loss(predictions: [Double], targets: [Double]) -> Double {
        guard !predictions.isEmpty, predictions.count == targets.count else { return 0 }
        let sum = zip(predictions, targets).reduce(0.0) { acc, pair in
            let d = pair.1 - pair.0
            return acc + d * d
        }
        return sum / Double(predictions.count)
    }

    /// Gradient of MSE w.r.t. prediction: (prediction − target)
    /// The 2/n factor is omitted — absorbed into the learning rate.
    func gradient(prediction: Double, target: Double) -> Double {
        prediction - target
    }
}

// MARK: - Huber

struct HuberCostFunction: CostFunction {
    let delta: Double

    func loss(predictions: [Double], targets: [Double]) -> Double {
        guard !predictions.isEmpty, predictions.count == targets.count else { return 0 }
        let sum = zip(predictions, targets).reduce(0.0) { acc, pair in
            let error = pair.1 - pair.0
            let absError = abs(error)
            let elementLoss = absError <= delta
                ? 0.5 * error * error
                : delta * (absError - 0.5 * delta)
            return acc + elementLoss
        }
        return sum / Double(predictions.count)
    }

    /// Gradient of Huber loss w.r.t. prediction.
    /// Within ±delta behaves like MSE (smooth); outside clips to ±delta (linear, bounded gradient).
    func gradient(prediction: Double, target: Double) -> Double {
        let error = prediction - target
        let absError = abs(error)
        return absError <= delta ? error : (error > 0 ? delta : -delta)
    }
}
