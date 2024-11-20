//
//  OrganismModel.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/16/24.
//

import Combine
import Foundation

struct SensorInput: Equatable, Sendable {
    let lightLevel: CGFloat
    let depth: CGFloat
    let totalTimeElapsed: TimeInterval
}

actor OrganismModel {
    enum Action: Sendable {
        case moveUp
        case moveDown
    }

    enum Direction: CGFloat, Sendable {
        case left = -1
        case right = 1
    }
    
    var actionPublisher: AsyncStream<Action> {
        AsyncStream { continuation in
            self.actionContinuation = continuation
        }
    }
    private(set) var direction: Direction = .left
    
    @Published private var energy = 100
    var isMoving = false
    
    private var actionContinuation: AsyncStream<Action>.Continuation?
    
    func handleChanges(_ input: SensorInput) async {
        await calculateNextAction()
    }
    
    func setIsMoving(_ moving: Bool) async {
        isMoving = moving
    }
    
    private func calculateNextAction() async {
        if !isMoving {
            let action: Action = Bool.random() ? .moveUp : .moveDown
            direction = direction == .left ? .right : .left
            

            actionContinuation?.yield(action)
        }
    }
}
