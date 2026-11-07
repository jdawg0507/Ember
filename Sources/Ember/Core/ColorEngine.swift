import Foundation
import CoreGraphics

/// Represents normalized RGB color multipliers (0.0 ... 1.0).
public struct RGBMultiplier: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0.0), 1.0)
        self.green = min(max(green, 0.0), 1.0)
        self.blue = min(max(blue, 0.0), 1.0)
    }

    public static let neutral = RGBMultiplier(red: 1.0, green: 1.0, blue: 1.0)
}

/// Special color modes supported by Ember.
public enum SpecialMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "Standard"
    case darkroom = "Darkroom (Red)"
    case movie = "Movie Mode"
    case grayscale = "Grayscale"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .none:
            return "Follows your scheduled solar color temperature."
        case .darkroom:
            return "Eliminates all green and blue light; preserves night-adapted vision."
        case .movie:
            return "Milder warming that preserves shadow detail and contrast."
        case .grayscale:
            return "Removes all color to reduce screen stimulation."
        }
    }
}

/// Computes RGB multipliers and gamma lookup tables from Kelvin color temperatures.
public enum ColorEngine {
    /// Baseline neutral daylight reference temperature in Kelvin.
    public static let referenceKelvin: Double = 6500.0
    public static let minimumKelvin: Double = 1200.0
    public static let maximumKelvin: Double = 6500.0

    /// Converts a color temperature in Kelvin to RGB multipliers using the Planckian blackbody locus approximation.
    /// Returns multipliers normalized so that 6500K yields (1.0, 1.0, 1.0).
    public static func multipliers(forKelvin kelvin: Double, mode: SpecialMode = .none) -> RGBMultiplier {
        switch mode {
        case .darkroom:
            // Pure red channel for astronomical & darkroom use; completely zero out green & blue
            return RGBMultiplier(red: 1.0, green: 0.0, blue: 0.0)

        case .grayscale:
            // Desaturate current temperature to grayscale luminance
            let base = rawKelvinToRGB(kelvin)
            let luminance = 0.299 * base.red + 0.587 * base.green + 0.114 * base.blue
            return RGBMultiplier(red: luminance, green: luminance, blue: luminance)

        case .movie:
            // Movie mode softens the temperature curve to maintain shadow detail
            let movieKelvin = max(kelvin, 3400.0)
            let raw = rawKelvinToRGB(movieKelvin)
            return normalize(raw: raw)

        case .none:
            let raw = rawKelvinToRGB(kelvin)
            return normalize(raw: raw)
        }
    }

    /// Generates hardware gamma ramp tables for a given color multiplier across `tableSize` entries (typically 256 or 1024).
    public static func generateGammaRamp(
        multiplier: RGBMultiplier,
        mode: SpecialMode = .none,
        tableSize: Int = 256
    ) -> (red: [Float], green: [Float], blue: [Float]) {
        guard tableSize > 1 else {
            return ([0.0], [0.0], [0.0])
        }

        var redTable = [Float](repeating: 0, count: tableSize)
        var greenTable = [Float](repeating: 0, count: tableSize)
        var blueTable = [Float](repeating: 0, count: tableSize)

        let divisor = Float(tableSize - 1)

        for i in 0..<tableSize {
            let normalizedInput = Float(i) / divisor

            switch mode {
            case .darkroom:
                // Boost red contrast in darkroom mode while zeroing green and blue
                let redVal = pow(normalizedInput, 0.95) * Float(multiplier.red)
                redTable[i] = min(max(redVal, 0.0), 1.0)
                greenTable[i] = 0.0
                blueTable[i] = 0.0

            case .grayscale:
                let grayVal = normalizedInput * Float(multiplier.red)
                redTable[i] = grayVal
                greenTable[i] = grayVal
                blueTable[i] = grayVal

            case .movie, .none:
                redTable[i] = normalizedInput * Float(multiplier.red)
                greenTable[i] = normalizedInput * Float(multiplier.green)
                blueTable[i] = normalizedInput * Float(multiplier.blue)
            }
        }

        return (red: redTable, green: greenTable, blue: blueTable)
    }

    // MARK: - Internal Calculations

    /// Computes raw Planckian blackbody RGB (Tanner Helland algorithm).
    private static func rawKelvinToRGB(_ kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let clamped = min(max(kelvin, 1000.0), 10000.0)
        let temp = clamped / 100.0

        var r: Double
        var g: Double
        var b: Double

        // Calculate Red
        if temp <= 66.0 {
            r = 255.0
        } else {
            let x = temp - 60.0
            r = 329.698727446 * pow(x, -0.1332047592)
        }

        // Calculate Green
        if temp <= 66.0 {
            g = 99.4708025861 * log(temp) - 161.1195681661
        } else {
            let x = temp - 60.0
            g = 288.1221695283 * pow(x, -0.0755148492)
        }

        // Calculate Blue
        if temp >= 66.0 {
            b = 255.0
        } else if temp <= 19.0 {
            b = 0.0
        } else {
            let x = temp - 10.0
            b = 138.5177312231 * log(x) - 305.0447927307
        }

        return (
            red: min(max(r, 0.0), 255.0),
            green: min(max(g, 0.0), 255.0),
            blue: min(max(b, 0.0), 255.0)
        )
    }

    /// Normalizes raw blackbody values against reference 6500K so 6500K equals exactly (1.0, 1.0, 1.0).
    private static func normalize(raw: (red: Double, green: Double, blue: Double)) -> RGBMultiplier {
        let ref = rawKelvinToRGB(referenceKelvin)
        let normR = min(raw.red / ref.red, 1.0)
        let normG = min(raw.green / ref.green, 1.0)
        let normB = min(raw.blue / ref.blue, 1.0)
        return RGBMultiplier(red: normR, green: normG, blue: normB)
    }
}

