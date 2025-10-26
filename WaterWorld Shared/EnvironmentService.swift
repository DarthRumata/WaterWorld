import Foundation
import CoreGraphics

/// Encapsulates environment-related calculations (light curve and attenuation).
struct EnvironmentService {
    // ln(depthLightLevel / surfaceLightLevel) / depth
    private let lightDecayRate: CGFloat = -0.069_314_718_055_9945

    /// Computes the light level at a given depth based on the surface light level.
    /// - Parameters:
    ///   - surfaceLight: The base light level at the surface (0...maxLight).
    ///   - depth: Normalized depth value used for attenuation.
    /// - Returns: The attenuated light level at the specified depth.
    func attenuatedLight(surfaceLight: Double, depth: CGFloat) -> CGFloat {
        CGFloat(surfaceLight) * exp(depth * lightDecayRate)
    }

    /// Computes the base light level at the surface for a given day progress.
    /// - Parameters:
    ///   - maxLight: Maximum light level.
    ///   - dayProgress: Fraction of the day (0.0...1.0), where 0 is sunrise, 0.25 noon, 0.5 sunset.
    /// - Returns: The base light level at the surface.
    func baseLightLevel(maxLight: Double, dayProgress: Double) -> Double {
        if dayProgress <= 0.25 {
            // Morning to noon (lightLevel increases from 0 to max)
            return maxLight * (dayProgress * 4)
        } else if dayProgress <= 0.5 {
            // Noon to sunset (lightLevel decreases from max to 0)
            return maxLight * (1 - ((dayProgress - 0.25) * 4))
        } else {
            // Night
            return 0
        }
    }
}
