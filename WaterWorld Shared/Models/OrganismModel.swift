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
    // Logical depth updated immediately on action — used for game logic (predation)
    // to avoid reading mid-animation SpriteKit position.
    private(set) var logicalDepth: Double = GlobalConstants.maxDepth * 0.5

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
        initialDepth: Double,
        onDeath: @escaping @MainActor @Sendable (OrganismModel, CauseOfDeath) -> Void
    ) {
        self.logicalDepth = initialDepth
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

    // Phase 1 — called in parallel TaskGroup. Returns nil if organism is dead.
    func prepareNextAction(lightLevel: Double, depth: Double, dayProgress: Double) async -> (state: OrganismState, action: Action)? {
        if isDead { return nil }
        let lightGain = energyCalculator.energyGain(fromLightLevel: lightLevel)
        energy = min(energy - GlobalConstants.idleEnergyLoss + lightGain, GlobalConstants.maxEnergy)
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
        let action = await brain.computeAction(for: state)
        guard !isDead else { return nil }
        return (state, action)
    }

    // Phase 2 — called sequentially after all Phase 1 tasks complete.
    func applyResult(state: OrganismState, action: Action) async {
        guard !isDead else { return }
        if action != .wait { direction = direction == .left ? .right : .left }
        // Update logical depth immediately — avoids reading mid-animation position next tick
        let depthStep = GlobalConstants.maxDepth * Double(GlobalConstants.movementPaceFraction) // = 4.0
        if action == .moveUp   { logicalDepth = max(0, logicalDepth - depthStep) }
        else if action == .moveDown { logicalDepth = min(GlobalConstants.maxDepth, logicalDepth + depthStep) }
        actionContinuation?.yield(action)
        spentEnergy(by: action)
        Task { await tracker.track(action: action, dayProgress: state.dayProgress) }
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
        Task { @MainActor in await self.handleDeath(cause: .predation) }
    }

    // Private logic

    private func handleDeath(cause: CauseOfDeath) async {
        await brain.reportDeath()
        await onDeath(self, cause)
        let lifespan = await tracker.reportGatheredStatistics(forName: name)
        await QLearningStore.shared.recordLifespan(days: lifespan)
    }

    private func observeEnergyChanges() async {
        for await energyValue in $energy.values {
            if energyValue <= 0 {
                if !isDead {
                    isDead = true
                    finishStreams()
                    await handleDeath(cause: .energyDepletion)
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

