import Foundation

enum PredatorsIntensity: Int, CaseIterable {
    case off = 0
    case low
    case medium
    case high

    var factor: Double {
        switch self {
        case .off: return 0.0
        case .low: return 1.0
        case .medium: return 3.0
        case .high: return 6.0
        }
    }
}
