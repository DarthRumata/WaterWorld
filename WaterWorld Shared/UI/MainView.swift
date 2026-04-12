//
//  MainView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/24/24.
//
import SwiftUI

struct OrganismSelection {
    let model: OrganismModel
    let network: NeuralNetwork?
}

struct MainView: View {
    @State private var selection: OrganismSelection?
    @State private var hudModel: GameHUDModel?

    var body: some View {
        VStack(spacing: 0) {
            if let hudModel {
                GameHUDView(hud: hudModel)
            }

            ZStack {
                SpriteKitContainer(
                    onTapOrganism: { self.selection = $0 },
                    onSceneReady: { self.hudModel = $0 }
                )

                if let selection, let network = selection.network {
                    OrganismPopover(model: selection.model, network: network) {
                        self.selection = nil
                    }
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        .overlay(alignment: .top) {
            LearningWarningBanner()
        }
    }
}
