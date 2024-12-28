//
//  SpriteKitContainer.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/24/24.
//

import Cocoa
import SpriteKit
import SwiftUI

struct SpriteKitContainer: NSViewRepresentable {
    let onTapOrganism: (OrganismModel?) -> Void

    func makeNSView(context: Context) -> SKView {
        let skView = SKView()
        let scene = GameScene.newGameScene()

        // Pass the callback to the scene
        scene.onTapOrganism = onTapOrganism
        
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.ignoresSiblingOrder = true

        skView.presentScene(scene)
        
        return skView
    }

    func updateNSView(_ nsView: SKView, context: Context) {
        
    }
}
