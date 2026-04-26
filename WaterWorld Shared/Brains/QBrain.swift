//
//  QBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

import Foundation

typealias ExperienceReporter = @Sendable (UUID, OrganismState, OrganismState?, Int) async -> Void

actor QBrain: BrainProtocol {
    let brainId: UUID = UUID()
    private let reportExperience: ExperienceReporter
    private let agentPolicy: AgentPolicy
    private var previousState: (OrganismState, Int)?

    init(reportExperience: @escaping ExperienceReporter, agentPolicy: AgentPolicy) {
        self.reportExperience = reportExperience
        self.agentPolicy = agentPolicy
    }

    func computeAction(for state: OrganismState) async -> OrganismModel.Action {
        let snapshot = await agentPolicy.currentSnapshot()

        if let prev = previousState {
            await reportExperience(brainId, prev.0, state, prev.1)
        }

        let actionIndex: Int
        if Double.random(in: 0..<1) < snapshot.epsilon {
            actionIndex = Int.random(in: 0..<OrganismModel.Action.allCases.count)
        } else {
            let q = snapshot.network.predict(inputs: state.normalized)
            actionIndex = q.indices.max(by: { q[$0] < q[$1] }) ?? 0
        }

        previousState = (state, actionIndex)
        return OrganismModel.Action.allCases[actionIndex]
    }

    func reportDeath() async {
        if let prev = previousState {
            await reportExperience(brainId, prev.0, nil, prev.1)
            previousState = nil
        }
    }
}
