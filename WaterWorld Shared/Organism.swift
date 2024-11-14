//
//  Organism.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/11/24.
//

import SpriteKit

class Organism: SKNode {
    private let bubble: SKShapeNode
    private let nucleus: SKShapeNode

    init(position: CGPoint, color: SKColor, radius: CGFloat = 20.0) {
        // Create the bubble shape node
        self.bubble = SKShapeNode(circleOfRadius: radius)
        self.bubble.fillColor = color
        self.bubble.strokeColor = .clear
        self.bubble.zPosition = 1

        // Create the nucleus shape node
        self.nucleus = SKShapeNode(circleOfRadius: radius * 0.3)
        self.nucleus.fillColor = .white
        self.nucleus.strokeColor = .clear
        self.nucleus.zPosition = 2

        super.init()

        self.position = position
        self.zPosition = 1

        // Add the bubble and nucleus to the organism node
        self.addChild(self.bubble)
        self.addChild(self.nucleus)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        // Add your interaction code here
        // For example, print organism details or change color
        print("Organism clicked at position: \(self.position)")
    }

    // Movement methods and other functionalities remain the same
    func startMovement() {
        // Define the movement up and down
        let moveUp = SKAction.moveBy(x: 0, y: 100, duration: 2.0)
        let moveDown = SKAction.moveBy(x: 0, y: -100, duration: 2.0)
        let wait = SKAction.wait(forDuration: 1.0)

        let sequence = SKAction.sequence([moveUp, wait, moveDown, wait])
        let repeatForever = SKAction.repeatForever(sequence)
        self.run(repeatForever)
    }

    func changeColor(_ newColor: SKColor) {
        let colorChange = SKAction.colorize(with: SKColor.red, colorBlendFactor: 1.0, duration: 0.5)
        self.bubble.run(colorChange)
    }

    func moveUp() {
        let moveUp = SKAction.moveTo(y: self.scene!.size.height * 0.8, duration: 2.0)
        self.run(moveUp)
    }

    func moveDown() {
        let moveDown = SKAction.moveTo(y: self.scene!.size.height * 0.2, duration: 2.0)
        self.run(moveDown)
    }
}
