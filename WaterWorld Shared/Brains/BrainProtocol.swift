//
//  BrainProtocol.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/7/24.
//

protocol BrainProtocol: Actor {
    func computeAction(for state: OrganismState) async -> OrganismModel.Action
    func reportDeath() async
}

extension BrainProtocol {
    func reportDeath() async {}
}
