//
//  QBrain.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 9/30/25.
//

actor QBrain: BrainProtocol {
    var neuralNetwork: NeuralNetwork? {
        get async {
            await qLearner.mainNetwork
        }
    }
    
    private let qLearner: QLearner
    private var previousState: (SensorInput, Int)?
    
    init(qLearner: QLearner) {
        self.qLearner = qLearner
    }
    
    func calculateResponse(on input: SensorInput) async -> OrganismModel.Action {
        let actionIndex = await qLearner.provideActionIndex(for: input)
        
        if let previousState {
            await qLearner.reportStep(
                currentState: previousState.0,
                nextState: input,
                actionIndex: previousState.1,
                didDie: false
            )
        }
        
        previousState = (input, actionIndex)
        
        return OrganismModel.Action.allCases[actionIndex]
    }
    
    func finishEpisode(didDie: Bool) async {
        if let previousState {
            await qLearner.reportStep(
                currentState: previousState.0,
                nextState: nil,
                actionIndex: previousState.1,
                didDie: didDie
            )
            self.previousState = nil
        }
    }
}

