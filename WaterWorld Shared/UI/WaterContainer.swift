//
//  WaterContainer.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/13/24.
//

import SpriteKit

class WaterContainer: SKSpriteNode {
    override init(texture: SKTexture?, color: NSColor, size: CGSize) {
        super.init(texture: texture, color: color, size: size)

        let boundaryRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        physicsBody = SKPhysicsBody(edgeLoopFrom: boundaryRect)
        physicsBody?.categoryBitMask = PhysicsCategory.boundary
        physicsBody?.isDynamic = false // Boundaries should not move
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(sceneSize: CGSize) {
        size = CGSize(width: sceneSize.width, height: sceneSize.height)
    }
}
