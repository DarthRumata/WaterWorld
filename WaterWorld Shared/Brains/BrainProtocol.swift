//
//  BrainProtocol.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/7/24.
//

protocol BrainProtocol: Actor {
    func calculateResponse(on input: OrganismState) async -> OrganismModel.Action
    func reportDeath() async
    func updatePolicy(network: NeuralNetwork, epsilon: Double) async
}

extension BrainProtocol {
    func reportDeath() async {}
    func updatePolicy(network: NeuralNetwork, epsilon: Double) async {}
}
