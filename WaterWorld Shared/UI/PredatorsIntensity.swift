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
        case .low:    return 0.10
        case .medium: return 0.20
        case .high:   return 0.40
        }
    }

    /// Minimum attacks per night regardless of population size.
    var minimumAttacksPerNight: Int {
        switch self {
        case .off:    return 0
        case .low:    return 2
        case .medium: return 6
        case .high:   return 10
        }
    }
}
