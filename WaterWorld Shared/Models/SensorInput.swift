//
//  SensorInput.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/7/24.
//

import Foundation

struct SensorInput: Equatable, Sendable {
    let lightLevel: Double
    let depth: Double
    let dayProgress: Double
    let energy: Double
}
