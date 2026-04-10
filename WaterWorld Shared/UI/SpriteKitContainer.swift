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
    let onTapOrganism: (OrganismSelection?) -> Void
    let onSceneReady: (GameHUDModel) -> Void

    func makeNSView(context: Context) -> SKView {
        let skView = SKView()
        let scene = GameScene.newGameScene()

        scene.onTapOrganism = onTapOrganism
        let hudModel = scene.hudModel
        Task { @MainActor in onSceneReady(hudModel) }

        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.ignoresSiblingOrder = true

        skView.presentScene(scene)

        return skView
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}
