/// Tracks a running mean and variance of prediction errors using Welford's online algorithm.
/// Derives an adaptive surprise threshold — mean + sigmaMultiplier·σ — so that
/// "surprising" experiences are defined relative to what the network currently finds typical,
/// rather than a hardcoded constant.
struct SurpriseThresholdTracker {
    private(set) var mean: Double = 0
    private var m2: Double = 0
    private var count: Int = 0
    let sigmaMultiplier: Double

    // Default 1.5σ → ~6.7% of samples exceed the threshold in a normal distribution.
    // TD errors are right-skewed (death/attack events create heavy tail), so in practice
    // the surprise rate will be somewhat higher — which is fine for replay prioritization.
    init(sigmaMultiplier: Double = 1.5) {
        self.sigmaMultiplier = sigmaMultiplier
    }

    /// Observes a new (prediction, target) pair and returns whether the error is surprising.
    /// Always returns false until at least 2 samples are recorded.
    mutating func observe(prediction: Double, target: Double) -> Bool {
        let error = abs(prediction - target)
        count += 1
        let delta = error - mean
        mean += delta / Double(count)
        m2 += delta * (error - mean)
        guard count > 1 else { return false }
        let std = (m2 / Double(count - 1)).squareRoot()
        return error > mean + sigmaMultiplier * std
    }
}
