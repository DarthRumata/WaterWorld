//
//  OrganismModel.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/16/24.
//

import Combine
import Foundation

actor OrganismModel: Equatable {
    enum Action: Sendable {
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
    private(set) var direction: Direction = .left
    
    var actionPublisher: AsyncStream<Action> {
        AsyncStream { continuation in
            self.actionContinuation = continuation
        }
    }
    
    // Private State
    
    @Published private var energy = 100
    private var isBusy = false
    
    private var isDead: Bool {
        energy <= 0
    }
    
    // Triggers
    
    private var actionContinuation: AsyncStream<Action>.Continuation?
    
    // Handlers
    
    private let onDeath: @MainActor @Sendable (UUID) -> Void
    
    // Dependencies
    
    private let brain: BrainProtocol
    
    init(brain: BrainProtocol, onDeath: @escaping @MainActor @Sendable (UUID) -> Void) {
        self.brain = brain
        self.onDeath = onDeath
        
        Task {
            await observeEnergyChanges()
        }
    }
    
    // Public methods
    
    func handleChanges(_ input: SensorInput) async {
        if isBusy || isDead { return }
        
        isBusy = true
        
        await calculateNextAction(input: input)
    }
    
    func setIsBusy(_ busy: Bool) async {
        isBusy = busy
    }
    
    // Private logic
    
    private func observeEnergyChanges() async {
        for await energyValue in $energy.values {
            if energyValue <= 0 {
                await onDeath(id)
            }
        }
    }
    
    private func calculateNextAction(input: SensorInput) async {
        let action: Action = await brain.calculateResponse(on: input)
   
        if action != .wait {
            direction = direction == .left ? .right : .left
        }
            
        actionContinuation?.yield(action)
        
        gainEnergy(fromLightLevel: input.lightLevel)
        spentEnergy(by: action)
    }
    
    private func spentEnergy(by action: Action) {
        if action == .wait {
            energy -= 1
        } else {
            energy -= 2
        }
    }
    
    private func gainEnergy(fromLightLevel lightLevel: CGFloat) {
        let gain: Int
        switch lightLevel {
        case 7...10:
            gain = 5
        case 5..<7:
            gain = 3
        case 2..<5:
            gain = 2
        default:
            gain = 0
        }
        
        energy += gain
    }
}
