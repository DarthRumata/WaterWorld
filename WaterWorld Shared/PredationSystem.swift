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
        let raw = Int(config.killBudgetFactor)
        let budget = max(0, min(raw, config.maxKillsPerNight))
        guard budget > 0 else { return [] }

        // Attack density peaks at midnight and fades toward sunset/dawn.
        // w(t) = 0.5 × (1 − cos(2π × t / T)) — sine bell centered at T/2.
        // Generated via rejection sampling: propose uniform t, accept with probability w(t).
        var times: [TimeInterval] = []
        while times.count < budget {
            let t = Double.random(in: 0..<config.nightDuration)
            let weight = 0.5 * (1 - cos(2 * .pi * t / config.nightDuration))
            if Double.random(in: 0...1) < weight {
                times.append(t)
            }
        }
        return times.sorted()
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
