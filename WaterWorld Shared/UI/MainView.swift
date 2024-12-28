//
//  MainView.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/24/24.
//
import SwiftUI

struct OrganismUIModel {
    let id: String
    let name: String
    let neuralNetwork: NeuralNetwork
}

struct MainView: View {
    @State private var selectedOrganismModel: OrganismModel?

    var body: some View {
        ZStack {
            // SpriteKit scene
            SpriteKitContainer { organismModel in
                self.selectedOrganismModel = organismModel
            }

            // Neural network overlay
            if let selectedOrganismModel {
                OrganismPopover(model: selectedOrganismModel) {
                    self.selectedOrganismModel = nil
                }
                    .frame(width: 450, height: 300) // Adjust size
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .transition(.opacity) // Add smooth appearance/disappearance
                    .zIndex(1)
            }
        }
    }
}
