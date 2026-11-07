import Foundation

/// Calculated astronomical solar times for a given day and location.
public struct SolarTimes: Equatable, Sendable {
    public let dawn: Date
    public let sunrise: Date
    public let solarNoon: Date
    public let sunset: Date
    public let dusk: Date

    public init(dawn: Date, sunrise: Date, solarNoon: Date, sunset: Date, dusk: Date) {
        self.dawn = dawn
        self.sunrise = sunrise
        self.solarNoon = solarNoon
        self.sunset = sunset
        self.dusk = dusk
    }
}

/// The daily solar phase of the day.
public enum SolarPhase: String, CaseIterable, Sendable {
    case day = "Daytime"
    case sunsetTransition = "Sunset Transition"
    case sunset = "Sunset / Evening"
    case bedtimeTransition = "Bedtime Transition"
    case bedtime = "Bedtime"
    case dawnTransition = "Dawn Transition"

    public var iconName: String {
        switch self {
        case .day:
            return "sun.max.fill"
        case .sunsetTransition, .sunset:
            return "sunset.fill"
        case .bedtimeTransition, .bedtime:
            return "moon.stars.fill"
        case .dawnTransition:
            return "sunrise.fill"
        }
    }
}

/// Engine for calculating solar positions, astronomical events, and scheduled color temperatures.
public enum SolarEngine {

    // MARK: - Astronomical Solar Calculations

    /// Computes accurate sunrise, sunset, and civil twilight for a given latitude, longitude, and date using NOAA equations.
    public static func calculateSolarTimes(
        latitude: Double,
        longitude: Double,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> SolarTimes {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard calendar.date(from: components) != nil else {
            let now = date
            return SolarTimes(dawn: now, sunrise: now, solarNoon: now, sunset: now, dusk: now)
        }

        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let gamma = (2.0 * .pi / 365.0) * (dayOfYear - 1.0) // Fractional year in radians

        // Equation of time in minutes
        let eqTime = 229.18 * (
            0.000075 +
            0.001868 * cos(gamma) -
            0.032077 * sin(gamma) -
            0.014615 * cos(2.0 * gamma) -
            0.040849 * sin(2.0 * gamma)
        )

        // Solar declination angle in radians
        let declination = 0.006918 -
            0.399912 * cos(gamma) +
            0.070257 * sin(gamma) -
            0.006758 * cos(2.0 * gamma) +
            0.000907 * sin(2.0 * gamma) -
            0.002697 * cos(3.0 * gamma) +
            0.00148 * sin(3.0 * gamma)

        let latRad = latitude * .pi / 180.0

        // Zenith for official sunrise/sunset = 90.833° (accounting for atmospheric refraction and solar disc)
        let zenithOfficial = 90.833 * .pi / 180.0
        // Zenith for civil twilight = 96.0° (sun 6° below horizon)
        let zenithCivil = 96.0 * .pi / 180.0

        let noonUtcMinutes = 720.0 - (4.0 * longitude) - eqTime

        func hourAngle(forZenith zenith: Double) -> Double? {
            let cosH = (cos(zenith) - (sin(latRad) * sin(declination))) / (cos(latRad) * cos(declination))
            if cosH > 1.0 || cosH < -1.0 {
                return nil // Polar day or polar night
            }
            return acos(cosH) * 180.0 / .pi
        }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let startOfDayUtc = utcCalendar.date(from: components) else {
            let now = date
            return SolarTimes(dawn: now, sunrise: now, solarNoon: now, sunset: now, dusk: now)
        }

        func dateFromUtcMinutes(_ minutes: Double) -> Date {
            return startOfDayUtc.addingTimeInterval(minutes * 60.0)
        }

        let solarNoonDate = dateFromUtcMinutes(noonUtcMinutes)

        let officialHA = hourAngle(forZenith: zenithOfficial) ?? 90.0
        let sunriseDate = dateFromUtcMinutes(noonUtcMinutes - (officialHA * 4.0))
        let sunsetDate = dateFromUtcMinutes(noonUtcMinutes + (officialHA * 4.0))

        let civilHA = hourAngle(forZenith: zenithCivil) ?? (officialHA + 6.0)
        let dawnDate = dateFromUtcMinutes(noonUtcMinutes - (civilHA * 4.0))
        let duskDate = dateFromUtcMinutes(noonUtcMinutes + (civilHA * 4.0))

        return SolarTimes(
            dawn: dawnDate,
            sunrise: sunriseDate,
            solarNoon: solarNoonDate,
            sunset: sunsetDate,
            dusk: duskDate
        )
    }

    /// Evaluates current solar elevation angle in degrees above the horizon.
    public static func solarElevation(
        latitude: Double,
        longitude: Double,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let times = calculateSolarTimes(latitude: latitude, longitude: longitude, date: date, calendar: calendar)
        let secondsFromNoon = date.timeIntervalSince(times.solarNoon)

        let hourAngleDegrees = secondsFromNoon / 240.0
        let hourAngleRad = hourAngleDegrees * .pi / 180.0

        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let gamma = (2.0 * .pi / 365.0) * (dayOfYear - 1.0)
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)

        let latRad = latitude * .pi / 180.0
        let sinElevation = sin(latRad) * sin(declination) + cos(latRad) * cos(declination) * cos(hourAngleRad)
        return asin(min(max(sinElevation, -1.0), 1.0)) * 180.0 / .pi
    }

    // MARK: - Temperature Schedule Computation

    /// Calculates the target Kelvin color temperature for the specified date and parameters.
    public static func targetKelvin(
        date: Date = Date(),
        solarTimes: SolarTimes,
        dayKelvin: Double,
        sunsetKelvin: Double,
        bedtimeKelvin: Double,
        wakeHour: Int = 7,
        wakeMinute: Int = 0,
        transitionDurationMinutes: Double = 60.0,
        calendar: Calendar = .current
    ) -> (kelvin: Double, phase: SolarPhase) {
        let transitionSeconds = max(transitionDurationMinutes, 1.0) * 60.0

        // Today's wake time
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        var wakeTodayComps = todayComponents
        wakeTodayComps.hour = wakeHour
        wakeTodayComps.minute = wakeMinute
        wakeTodayComps.second = 0

        guard let wakeToday = calendar.date(from: wakeTodayComps) else {
            return (dayKelvin, .day)
        }

        // Determine next upcoming wake time
        let upcomingWake: Date
        let previousWake: Date
        if date >= wakeToday {
            previousWake = wakeToday
            upcomingWake = calendar.date(byAdding: .day, value: 1, to: wakeToday)!
        } else {
            upcomingWake = wakeToday
            previousWake = calendar.date(byAdding: .day, value: -1, to: wakeToday)!
        }

        // Bedtime begins 9 hours before the upcoming wake time
        let bedtimeStart = upcomingWake.addingTimeInterval(-9.0 * 3600.0)
        let bedtimeEnd = bedtimeStart.addingTimeInterval(transitionSeconds)

        // Morning dawn transition begins transitionDuration before the wake time
        let dawnStart = upcomingWake.addingTimeInterval(-transitionSeconds)

        let sunsetStart = solarTimes.sunset.addingTimeInterval(-transitionSeconds)
        let sunsetEnd = solarTimes.sunset

        // 1. Dawn Transition leading up to wake
        if date >= dawnStart && date < upcomingWake {
            let progress = (date.timeIntervalSince(dawnStart)) / transitionSeconds
            let smoothed = smoothstep(progress)
            let current = lerp(from: bedtimeKelvin, to: dayKelvin, t: smoothed)
            return (current, .dawnTransition)
        }

        // 2. Daytime: Between previous wake and sunset transition
        if date >= previousWake && date < sunsetStart {
            return (dayKelvin, .day)
        }

        // 3. Sunset Transition: Transitioning from Day Kelvin to Sunset Kelvin
        if date >= sunsetStart && date < sunsetEnd {
            let progress = (date.timeIntervalSince(sunsetStart)) / transitionSeconds
            let smoothed = smoothstep(progress)
            let current = lerp(from: dayKelvin, to: sunsetKelvin, t: smoothed)
            return (current, .sunsetTransition)
        }

        // 4. Evening: Between sunset and bedtime start
        if date >= sunsetEnd && date < bedtimeStart {
            return (sunsetKelvin, .sunset)
        }

        // 5. Bedtime Transition: Transitioning from Sunset Kelvin to Bedtime Kelvin
        if date >= bedtimeStart && date < bedtimeEnd {
            let progress = (date.timeIntervalSince(bedtimeStart)) / transitionSeconds
            let smoothed = smoothstep(progress)
            let current = lerp(from: sunsetKelvin, to: bedtimeKelvin, t: smoothed)
            return (current, .bedtimeTransition)
        }

        // 6. Deep Bedtime
        return (bedtimeKelvin, .bedtime)
    }

    // MARK: - Mathematical Helpers

    /// Smooth S-curve (Hermite interpolation) for seamless transitions without visual banding.
    public static func smoothstep(_ edge0: Double = 0.0, _ edge1: Double = 1.0, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    /// Single-argument smoothstep over [0, 1].
    public static func smoothstep(_ t: Double) -> Double {
        let clamped = min(max(t, 0.0), 1.0)
        return clamped * clamped * (3.0 - 2.0 * clamped)
    }

    /// Linear interpolation between two values.
    public static func lerp(from: Double, to: Double, t: Double) -> Double {
        return from + (to - from) * t
    }
}
