//
//  OrganismModel.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/16/24.
//

import Combine
import Foundation

actor OrganismModel: Equatable {
    enum Action: Sendable, CaseIterable {
        case moveUp
        case moveDown
        case wait
    }

    enum Direction: CGFloat, Sendable {
        case left = -1
        case right = 1
    }
    
    static func == (lhs: OrganismModel, rhs: OrganismModel) -> Bool {
        lhs.id == rhs.id
    }
    
    // Public state
    
    let id = UUID()
    let name: String
    private(set) var direction: Direction = .left
    
    var actionPublisher: AsyncStream<Action> {
        AsyncStream { continuation in
            self.actionContinuation = continuation
        }
    }
    var inputsPublisher: AsyncStream<SensorInput> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.inputsContinuation = continuation
            if let lastInput {
                continuation.yield(lastInput)
            }
        }
    }
    
    // Private State
    
    @Published private(set) var energy = GlobalConstants.maxEnergy
    private var isBusy = false
    private var lastInput: SensorInput? = nil
    private(set) var isDead: Bool = false
    
    // Triggers
    
    private var actionContinuation: AsyncStream<Action>.Continuation?
    private var inputsContinuation: AsyncStream<SensorInput>.Continuation?
    
    // Handlers
    
    private let onDeath: @MainActor @Sendable (OrganismModel, CauseOfDeath) -> Void
    
    // Dependencies
    
    private let brain: BrainProtocol
    let logger: Logger
    private let tracker: OrganismTracker
    private let energyCalculator = EnergyCalculator()
    
    init(
        brain: BrainProtocol,
        name: String,
        logger: Logger,
        tracker: OrganismTracker,
        onDeath: @escaping @MainActor @Sendable (OrganismModel, CauseOfDeath) -> Void
    ) {
        self.brain = brain
        self.name = name
        self.logger = logger
        self.tracker = tracker
        self.onDeath = onDeath
        
        Task {
            await observeEnergyChanges()
        }
    }
    
    // Public methods
    func handleChanges(_ input: SensorInput) async {
        if isDead { return }
        
        isBusy = true
        
        energy -= GlobalConstants.idleEnergyLoss
        gainEnergy(fromLightLevel: input.lightLevel)
        lastInput = input
        inputsContinuation?.yield(input)
        await calculateNextAction(input: input)
    }
    
    func setIsBusy(_ busy: Bool) {
        isBusy = busy
    }
    
    func applyDamage(_ amount: Double) {
        if isDead { return }
        energy = max(0, energy - amount)
    }
    
    func kill() {
        if isDead { return }
        isDead = true
        // Set energy to 0 before reporting, without triggering another step
        energy = 0
        Task { @MainActor in
            await brain.finishEpisode(didDie: true)
            onDeath(self, .predation)
            await tracker.reportGatheredStatistics(forName: name)
        }
    }
    
    func finishEpisodeSurvived() async {
        await brain.finishEpisode(didDie: false)
    }

    func updateBrainNetwork(_ network: NeuralNetwork, epsilon: Double) async {
        await brain.updatePolicy(network: network, epsilon: epsilon)
    }
    
    // Private logic
    
    private func observeEnergyChanges() async {
        for await energyValue in $energy.values {
            if energyValue <= 0 {
                if !isDead {
                    isDead = true
                    await brain.finishEpisode(didDie: true)
                    await onDeath(self, .energyDepletion)
                    await tracker.reportGatheredStatistics(forName: name)
                }
                break
            }
        }
    }
    
    private func calculateNextAction(input: SensorInput) async {
        let action: Action = await brain.calculateResponse(on: input)
   
        if action != .wait {
            direction = direction == .left ? .right : .left
        }
            
        actionContinuation?.yield(action)
        
        spentEnergy(by: action)
        
        Task {
            await tracker.track(action: action, dayProgress: input.dayProgress)
//            await logger.log(
//                message: "t: \(input.dayProgress.formatted()) action: \(action), energy: \(energy)"
//            )
        }
    }
    
    private func spentEnergy(by action: Action) {
        if action != .wait {
            energy -= GlobalConstants.movementEnergyLoss
        }
    }
    
    private func gainEnergy(fromLightLevel lightLevel: CGFloat) {
        let gain = energyCalculator.energyGain(fromLightLevel: lightLevel)
        
        energy = min(gain + energy, GlobalConstants.maxEnergy)
    }
}

extension OrganismModel.Action: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .moveUp:
            "moveUp"
        case .moveDown:
            "moveDown"
        case .wait:
            "wait"
        }
    }
}

