//
//  ConsoleLogger.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/8/24.
//

actor ConsoleLogger: Logger {
    func log(message: String) {
        print("[Console] \(message)")
    }
}
