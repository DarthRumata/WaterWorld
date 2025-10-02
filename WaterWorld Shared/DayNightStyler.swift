//
//  DayNightStyler.swift
//  WaterWorld Shared
//
//  Extracted ambient color styling for day/night cycle.
//

import SpriteKit

struct DayNightStyler {
    // Public API
    static func skyColor(for progress: Double) -> SKColor {
        let p = CGFloat(progress)
        // Keyframe colors
        let sunrise = SKColor(red: 1.0, green: 0.68, blue: 0.42, alpha: 1.0) // warm peach
        let noon    = SKColor(red: 0.55, green: 0.80, blue: 0.98, alpha: 1.0) // soft sky blue
        let sunset  = SKColor(red: 0.99, green: 0.55, blue: 0.60, alpha: 1.0) // pinkish
        let night   = SKColor(red: 0.07, green: 0.12, blue: 0.25, alpha: 1.0) // deep navy

        if p <= 0.25 {
            let t = easeInOut(p / 0.25)
            return mixColors(sunrise, noon, t)
        } else if p <= 0.5 {
            let t = easeInOut((p - 0.25) / 0.25)
            return mixColors(noon, sunset, t)
        } else if p <= 0.75 {
            let t = easeInOut((p - 0.5) / 0.25)
            return mixColors(sunset, night, t)
        } else {
            let t = easeInOut((p - 0.75) / 0.25)
            return mixColors(night, sunrise, t)
        }
    }

    static func waterColor(for progress: Double) -> SKColor {
        // Subtle water tint: brighter by day, deeper by night
        let dayWater = SKColor(red: 0.45, green: 0.75, blue: 0.95, alpha: 0.7)
        let nightWater = SKColor(red: 0.10, green: 0.25, blue: 0.45, alpha: 0.7)
        let p = CGFloat(progress)

        // Envelope peaks at noon, zero at night
        let envelope: CGFloat
        if p <= 0.25 {
            envelope = p / 0.25
        } else if p <= 0.5 {
            envelope = 1 - (p - 0.25) / 0.25
        } else {
            envelope = 0
        }
        let t = easeInOut(envelope)
        return mixColors(nightWater, dayWater, t)
    }

    // MARK: - Internals

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        // Smoothstep easing for gentle transitions
        return t * t * (3 - 2 * t)
    }

    private static func mixColors(_ c1: SKColor, _ c2: SKColor, _ t: CGFloat) -> SKColor {
        let cs1 = c1.usingColorSpace(.sRGB) ?? c1
        let cs2 = c2.usingColorSpace(.sRGB) ?? c2
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        cs1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cs2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: 1.0
        )
    }
}

