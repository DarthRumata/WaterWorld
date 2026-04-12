//
//  QBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

typealias ExperienceReporter = @Sendable (OrganismState, OrganismState?, Int) async -> Void

actor QBrain: BrainProtocol {
    var neuralNetwork: NeuralNetwork? { nil }

    private let reportExperience: ExperienceReporter
    private let agentPolicy: AgentPolicy
    private var previousState: (OrganismState, Int)?

    init(reportExperience: @escaping ExperienceReporter, agentPolicy: AgentPolicy) {
        self.reportExperience = reportExperience
        self.agentPolicy = agentPolicy
    }

    func calculateResponse(on input: OrganismState) async -> OrganismModel.Action {
        let actionIndex = await agentPolicy.provideActionIndex(
            for: input.normalized,
            actionCount: OrganismModel.Action.allCases.count
        )

        if let previousState {
            await reportExperience(previousState.0, input, previousState.1)
        }

        previousState = (input, actionIndex)
        return OrganismModel.Action.allCases[actionIndex]
    }

    func reportDeath() async {
        if let previousState {
            await reportExperience(previousState.0, nil, previousState.1)
            self.previousState = nil
        }
    }

    func updatePolicy(network: NeuralNetwork, epsilon: Double) async {
        await agentPolicy.update(network: network, epsilon: epsilon)
    }
}
