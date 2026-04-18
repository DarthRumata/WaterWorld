import Foundation

struct OrganismState: Equatable, Sendable {
    let lightLevel: Double
    let depth: Double
    let dayProgress: Double
    let energy: Double
    let wasAttacked: Bool

    var normalized: [Double] {
        // dayProgress encoded as (sin, cos) so the network sees 0.0 and 1.0 as the
        // same point in the cycle rather than opposite ends of a scalar range.
        let angle = 2.0 * Double.pi * dayProgress
        return [
            lightLevel / GlobalConstants.maxLightLevel,
            depth / GlobalConstants.maxDepth,
            energy / GlobalConstants.maxEnergy,
            sin(angle),
            cos(angle)
            // wasAttacked intentionally excluded — reward signal only, not a network input
        ]
    }
}
