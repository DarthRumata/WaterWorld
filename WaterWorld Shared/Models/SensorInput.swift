//
//  SensorInput.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/7/24.
//

import Foundation

struct SensorInput: Equatable, Sendable {
    let lightLevel: CGFloat
    let depth: CGFloat
    let totalTimeElapsed: TimeInterval
}
