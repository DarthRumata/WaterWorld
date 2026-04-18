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

    // actionPublisher is stored — Organism subscribes once at init and must not lose the stream.
    let actionPublisher: AsyncStream<Action>

    // inputsPublisher is computed — recreated each time OrganismPopover opens,
    // immediately replaying lastInput so the view has data before the next tick.
    var inputsPublisher: AsyncStream<OrganismState> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            guard !isDead else { continuation.finish(); return }
            inputsContinuation = continuation
            if let lastInput { continuation.yield(lastInput) }
        }
    }

    // Private State

    @Published private(set) var energy = GlobalConstants.maxEnergy
    private var lastInput: OrganismState? = nil
    private(set) var isDead: Bool = false
    private var wasAttackedThisTick: Bool = false
    private var isProcessingAction: Bool = false

    // Triggers

    private var actionContinuation: AsyncStream<Action>.Continuation?
    private var inputsContinuation: AsyncStream<OrganismState>.Continuation?
    
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
        // Create streams once. AsyncStream calls the closure synchronously,
        // so continuations are set before any other code runs.
        var aCont: AsyncStream<Action>.Continuation!
        self.actionPublisher = AsyncStream(Action.self, bufferingPolicy: .bufferingNewest(1)) { aCont = $0 }

        self.actionContinuation = aCont

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
    func handleChanges(lightLevel: Double, depth: Double, dayProgress: Double) async {
        if isDead { return }

        // Apply idle loss and light gain atomically — only the final value is published
        // to $energy, so observeEnergyChanges sees the real outcome, not a transient negative.
        let lightGain = energyCalculator.energyGain(fromLightLevel: lightLevel)
        energy = min(energy - GlobalConstants.idleEnergyLoss + lightGain, GlobalConstants.maxEnergy)

        // Use post-passive energy so the brain sees a state consistent with lightLevel:
        // lightLevel and energy both reflect the same tick.
        let state = OrganismState(
            lightLevel: lightLevel,
            depth: depth,
            dayProgress: dayProgress,
            energy: energy,
            wasAttacked: wasAttackedThisTick
        )
        wasAttackedThisTick = false

        lastInput = state
        inputsContinuation?.yield(state)
        await calculateNextAction(input: state)
    }
    
    func applyDamage(_ amount: Double) {
        if isDead { return }
        energy = max(0, energy - amount)
        wasAttackedThisTick = true
    }
    
    func kill() {
        if isDead { return }
        isDead = true
        energy = 0
        finishStreams()
        Task { @MainActor in
            await brain.reportDeath()
            onDeath(self, .predation)
            let lifespan = await tracker.reportGatheredStatistics(forName: name)
            QLearningStore.shared.recordLifespan(days: lifespan)
        }
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
                    finishStreams()
                    await brain.reportDeath()
                    await onDeath(self, .energyDepletion)
                    await tracker.reportGatheredStatistics(forName: name)
                }
                break
            }
        }
    }
    
    private func finishStreams() {
        actionContinuation?.finish()
        actionContinuation = nil
        inputsContinuation?.finish()
        inputsContinuation = nil
    }

    private func calculateNextAction(input: OrganismState) async {
        let action: Action = await brain.calculateResponse(on: input)

        // Actor is reentrant at suspension points — kill() or applyDamage() may have
        // run while brain.calculateResponse was awaiting. Guard before any side effects.
        guard !isDead else { return }

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

