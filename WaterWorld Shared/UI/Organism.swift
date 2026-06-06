//
//  Organism.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/11/24.
//

@preconcurrency import Combine
import SpriteKit

enum PhysicsCategory {
    static let organism: UInt32 = 0x1 << 0
    static let boundary: UInt32 = 0x1 << 1
    // Add other categories if needed
}

class Organism: SKNode {
    var id: UUID {
        model.id
    }

    private let bubble: SKShapeNode
    private let nucleus: SKShapeNode

    private let onClick: (Organism) -> Void
    private let model: OrganismModel

    private var cancellables = Set<AnyCancellable>()

    init(model: OrganismModel, position: CGPoint, color: SKColor, radius: CGFloat, onClick: @escaping (Organism) -> Void) {
        // Create the bubble shape node
        bubble = SKShapeNode(circleOfRadius: radius)
        bubble.fillColor = color
        bubble.strokeColor = .clear
        bubble.zPosition = 1

        // Create the nucleus shape node
        nucleus = SKShapeNode(circleOfRadius: radius * 0.3)
        nucleus.fillColor = .white
        nucleus.strokeColor = .clear
        nucleus.zPosition = 2

        self.model = model
        self.onClick = onClick

        super.init()

        isUserInteractionEnabled = true

        self.position = position
        zPosition = 1

        // Add the bubble and nucleus to the organism node
        addChild(bubble)
        addChild(nucleus)

        let physics = SKPhysicsBody(circleOfRadius: radius)
        physics.allowsRotation = false
        physics.affectedByGravity = false
        physics.friction = 0.1
        physics.restitution = 0.5
        physics.linearDamping = 0.1
        physics.mass = 1
        physics.isDynamic = true
        physics.categoryBitMask = PhysicsCategory.organism
        physics.collisionBitMask = PhysicsCategory.boundary | PhysicsCategory.organism
        physics.contactTestBitMask = PhysicsCategory.organism

        physicsBody = physics

        listenModel()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onClick(self)
    }

    func changeColor(_ newColor: SKColor) {
        let colorChange = SKAction.colorize(with: SKColor.red, colorBlendFactor: 1.0, duration: 0.5)
        bubble.run(colorChange)
    }

    func moveUp() async { await moveToLogicalDepth() }
    func moveDown() async { await moveToLogicalDepth() }

    // Animates to the absolute position derived from logicalDepth — single source of truth.
    // Avoids reading mid-animation position, so no drift regardless of simulation speed.
    private func moveToLogicalDepth() async {
        guard let parentNode = parent else { return }
        let containerH = parentNode.frame.size.height
        let pace = containerH * GlobalConstants.movementPaceFraction
        let logDepth = CGFloat(await model.logicalDepth)
        let direction = await model.direction
        let radius = bubble.frame.width / 2

        let targetY = (1.0 - logDepth / CGFloat(GlobalConstants.maxDepth)) * containerH
        let targetX = position.x + direction.rawValue * pace

        let newPosition = CGPoint(
            x: max(radius, min(targetX, parentNode.frame.size.width - radius)),
            y: max(radius, min(targetY, containerH - radius))
        )

        guard position != newPosition else { return }
        if speed > 3 {
            position = newPosition
        } else {
            await run(SKAction.move(to: newPosition, duration: GlobalConstants.gameTickDuration))
        }
    }

    private func listenModel() {
        Task {
            for await action in model.actionPublisher {
                switch action {
                case .moveUp:
                    await moveUp()
                case .moveDown:
                    await moveDown()
                case .wait:
                    await wait()
                }
            }
        }
    }


    private func wait() async {
        guard speed <= 3 else { return }
        try? await Task.sleep(for: .seconds(GlobalConstants.gameTickDuration / speed))
    }
}
