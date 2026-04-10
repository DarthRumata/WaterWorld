//
//  BrainProtocol.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/7/24.
//

protocol BrainProtocol: Actor {
    func calculateResponse(on input: SensorInput) async -> OrganismModel.Action
    func finishEpisode(didDie: Bool) async
}

extension BrainProtocol {
    func finishEpisode(didDie: Bool) async {}
}
