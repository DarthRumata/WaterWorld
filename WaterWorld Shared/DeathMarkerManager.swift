import Foundation
import SpriteKit

/// Manages rendering of death markers that fade out over one in-game day.
@MainActor
final class DeathMarkerManager {
    private weak var container: SKNode?
    private let dayDuration: TimeInterval

    init(container: SKNode, dayDuration: TimeInterval) {
        self.container = container
        self.dayDuration = dayDuration
    }

    func addMarker(at position: CGPoint, cause: CauseOfDeath) {
        let color: SKColor = (cause == .predation) ? .red : .black
        // Slightly larger and rendered above organisms for visibility
        let radius: CGFloat = 6
        let dot = SKShapeNode(circleOfRadius: radius)
        dot.name = "death_marker"
        dot.fillColor = color
        dot.strokeColor = .clear
        dot.lineWidth = 0
        dot.isAntialiased = true
        dot.alpha = 1.0
        dot.position = position
        // Ensure marker renders above organisms and container contents
        dot.zPosition = 100
        container?.addChild(dot)

        let fade = SKAction.fadeOut(withDuration: dayDuration)
        dot.run(.sequence([fade, .removeFromParent()]))
    }
    
    func clearAll() {
        guard let container else { return }
        for child in container.children where child.name == "death_marker" {
            child.removeFromParent()
        }
    }
}

