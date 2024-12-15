//
//  ConsoleLogger.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/8/24.
//

actor ConsoleLogger: Logger {
    let lastProgress: Double = 0
    var actionsPerDay = [Int]()
    
    func log(message: String) {
        print("[Console] \(message)")
    }
    
    func track(action: OrganismModel.Action, dayProgress: Double) {
        if dayProgress > lastProgress {
            let dayActions = actionsPerDay[actionsPerDay.count - 1]
            actionsPerDay[actionsPerDay.count - 1] = dayActions + 1
        } else {
            actionsPerDay.append(1)
        }
    }
    
    func reportGatheredStatistics() {
        for (day, actionCount) in actionsPerDay.enumerated() {
            print("Day: \(day), actions: \(actionCount)")
        }
    }
}
