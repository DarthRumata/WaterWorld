//
//  SequenceBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/17/24.
//

actor SequenceBrain: BrainProtocol {
    private var actions: [OrganismModel.Action]
    
    init(actions: [OrganismModel.Action]) {
        self.actions = actions
    }
    
    func computeAction(for input: OrganismState) async -> OrganismModel.Action {
        guard !actions.isEmpty else {
            return .wait
        }

        return actions.removeFirst()
    }
}
