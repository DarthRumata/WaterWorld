//
//  OrganismTracker.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/17/24.
//

actor OrganismTracker {
    // Tracked data
    private var lastProgress: Double = 0
    private var actionsPerDay = [0]
    
    // Dependecies
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func track(action: OrganismModel.Action, dayProgress: Double) {
        if dayProgress > lastProgress {
            actionsPerDay[actionsPerDay.count - 1] += 1
        } else {
            actionsPerDay.append(1)
        }
        
        lastProgress = dayProgress
    }
    
    func reportGatheredStatistics(forName name: String) async {
        await logger.log(message: "Report for: \(name)")
        for (day, actionCount) in actionsPerDay.enumerated() {
            await logger.log(message: "Day: \(day), actions: \(actionCount)")
        }
    }
}
