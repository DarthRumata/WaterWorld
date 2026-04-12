//
//  RandomBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/7/24.
//

actor RandomBrain: BrainProtocol {
    func calculateResponse(on input: OrganismState) async -> OrganismModel.Action {
        let actions: [OrganismModel.Action] = [.moveUp, .moveDown, .wait]
        return actions.randomElement()!
    }
}
