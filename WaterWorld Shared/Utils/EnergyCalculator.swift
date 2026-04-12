//
//  EnergyCalculator.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/12/24.
//

import Foundation

class EnergyCalculator {
    /// Maximum net energy change per tick: best possible light minus idle cost.
    var maxGainPerTick: Double {
        energyGain(fromLightLevel: GlobalConstants.maxLightLevel) - GlobalConstants.idleEnergyLoss
    }

    /// Maximum net energy loss per tick: movement cost in total darkness.
    var maxLossPerTick: Double { GlobalConstants.movementEnergyLoss }

    func energyGain(fromLightLevel lightLevel: Double) -> Double {
        switch lightLevel {
        case 7 ... 10:
            return 14
        case 5..<7:
            return 9
        case 2..<5:
            return 5
        case 1..<2:
            return 4
        default:
            return 0
        }
    }
}
