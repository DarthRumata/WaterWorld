//
//  Logger.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/8/24.
//

protocol Logger: Actor {
    func log(message: String)
    func track(action: OrganismModel.Action, dayProgress: Double)
    func reportGatheredStatistics()
}
