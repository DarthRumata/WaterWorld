import Foundation

enum PredatorsIntensity: Int, CaseIterable {
    case off = 0
    case low
    case medium
    case high

    /// Fraction of the current population attacked per night.
    var populationFraction: Double {
        switch self {
        case .off:    return 0.0
        case .low:    return 0.05
        case .medium: return 0.10
        case .high:   return 0.20
        }
    }

    /// Minimum attacks per night regardless of population size.
    var minimumAttacksPerNight: Int {
        switch self {
        case .off:    return 0
        case .low:    return 1
        case .medium: return 3
        case .high:   return 5
        }
    }
}
