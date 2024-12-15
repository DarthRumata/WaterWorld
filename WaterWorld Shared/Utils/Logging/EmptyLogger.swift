//
//  EmptyLogger.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/8/24.
//

actor EmptyLogger: Logger {
    func track(action: OrganismModel.Action, dayProgress: Double) {
        
    }
    
    func reportGatheredStatistics() {
        
    }
    
    func log(message: String) {
        
    }
}
