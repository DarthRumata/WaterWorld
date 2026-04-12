import Foundation

struct OrganismState: Equatable, Sendable {
    let lightLevel: Double
    let depth: Double
    let dayProgress: Double
    let energy: Double
    let wasAttacked: Bool

    var normalized: [Double] {
        [
            lightLevel / GlobalConstants.maxLightLevel,
            depth / GlobalConstants.maxDepth,
            energy / GlobalConstants.maxEnergy,
            dayProgress
            // wasAttacked intentionally excluded — reward signal only, not a network input
        ]
    }
}
