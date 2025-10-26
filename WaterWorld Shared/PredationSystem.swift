import Foundation
import CoreGraphics

actor PredationSystem {
    struct Config: Sendable {
        var killBudgetFactor: Double // flat kills per night (based on predators)
        var maxKillsPerNight: Int = 6
        var nightDuration: TimeInterval
        var riskFromDepth: @Sendable (CGFloat) -> Double
    }

    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func planNightAttacks() -> [TimeInterval] {
        // Flat rate: kills per night derived from killBudgetFactor (not population-based)
        let raw = Int(config.killBudgetFactor)
        let budget = max(0, min(raw, config.maxKillsPerNight))
        guard budget > 0 else { return [] }

        // Evenly distributed with jitter across the night
        let base = config.nightDuration / Double(budget)
        return (0..<budget).map { i in
            let start = Double(i) * base
            let jitter = Double.random(in: 0..<(base * 0.8))
            return start + jitter
        }
    }

    func chooseTarget(from organisms: [(id: UUID, depth: CGFloat)]) -> UUID? {
        guard !organisms.isEmpty else { return nil }
        // Weighted by riskFromDepth(depth)
        let weights = organisms.map { max(0.0001, config.riskFromDepth($0.depth)) }
        let total = weights.reduce(0, +)
        var r = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return organisms[i].id }
        }
        return organisms.last?.id
    }
}
