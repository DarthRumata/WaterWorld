//
//  WaterContainer.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/13/24.
//

import SpriteKit

class WaterContainer: SKSpriteNode {
    func update(sceneSize: CGSize) {
        size = CGSize(width: sceneSize.width, height: sceneSize.height - 200)
    }
}
