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

private enum Constants {
    static let movementPace: CGFloat = 40
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
        physics.restitution = 0.1
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

    func moveUp() {
        Task {
            await move(by: CGPoint(x: model.direction.rawValue * Constants.movementPace, y: Constants.movementPace))
        }
    }

    func moveDown() {
        Task {
            await move(by: CGPoint(
                x: model.direction.rawValue * Constants.movementPace,
                y: -Constants.movementPace
            ))
        }
    }

    private func listenModel() {
        Task {
            for await action in await model.actionPublisher {
                switch action {
                case .moveUp:
                    moveUp()
                case .moveDown:
                    moveDown()
                case .wait:
                    await wait()
                }
            }
        }
    }

    private func move(by delta: CGPoint) async {
        guard let parentNode = parent else { return }

        // Calculate the proposed new position
        var newPosition = CGPoint(x: position.x + delta.x, y: position.y + delta.y)

        // Get the parent's size
        let parentSize = parentNode.frame.size

        // Define the organism's size (assuming it's a circle or square for simplicity)
        let organismRadius: CGFloat = bubble.frame.width / 2

        // Define the boundaries within which the organism can move
        let minX = organismRadius
        let maxX = parentSize.width - organismRadius
        let minY = organismRadius
        let maxY = parentSize.height - organismRadius

        // Clamp the new position within the boundaries
        newPosition.x = max(minX, min(newPosition.x, maxX))
        newPosition.y = max(minY, min(newPosition.y, maxY))

        if position != newPosition {
            let moveAction = SKAction.move(to: newPosition, duration: GlobalConstants.gameTickDuration)
            await run(moveAction)
        }
        await model.setIsBusy(false)
    }

    private func wait() async {
        try? await Task.sleep(for: .seconds(GlobalConstants.gameTickDuration / speed))
        await model.setIsBusy(false)
    }
}
