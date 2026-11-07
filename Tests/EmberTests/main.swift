import Foundation
import CoreGraphics
import EmberLib

var passedCount = 0
var failedCount = 0

func assertTest(_ condition: Bool, _ name: String, file: String = #file, line: Int = #line) {
    if condition {
        passedCount += 1
        print("  ✅ PASS: \(name)")
    } else {
        failedCount += 1
        print("  ❌ FAIL: \(name) (\(file):\(line))")
    }
}

print("🧪 Running Ember Test Suite...")

// MARK: - Color Engine Tests
print("\n[ColorEngine Tests]")
let dayMult = ColorEngine.multipliers(forKelvin: 6500.0)
assertTest(abs(dayMult.red - 1.0) < 0.001, "Daylight 6500K Red is neutral (1.0)")
assertTest(abs(dayMult.green - 1.0) < 0.001, "Daylight 6500K Green is neutral (1.0)")
assertTest(abs(dayMult.blue - 1.0) < 0.001, "Daylight 6500K Blue is neutral (1.0)")

let sunsetMult = ColorEngine.multipliers(forKelvin: 3400.0)
assertTest(abs(sunsetMult.red - 1.0) < 0.001, "Sunset 3400K retains full red")
assertTest(sunsetMult.green < 0.95, "Sunset 3400K attenuates green")
assertTest(sunsetMult.blue < 0.60 && sunsetMult.blue > 0.20, "Sunset 3400K warms blue appropriately")

let bedtimeMult = ColorEngine.multipliers(forKelvin: 1900.0)
assertTest(abs(bedtimeMult.red - 1.0) < 0.001, "Bedtime 1900K retains full red")
assertTest(bedtimeMult.blue < 0.20, "Bedtime 1900K significantly cuts blue")

let candleMult = ColorEngine.multipliers(forKelvin: 1200.0)
assertTest(candleMult.blue < 0.01, "Candle 1200K eliminates blue")

let darkroomMult = ColorEngine.multipliers(forKelvin: 6500.0, mode: .darkroom)
assertTest(darkroomMult.red == 1.0, "Darkroom mode Red is 1.0")
assertTest(darkroomMult.green == 0.0, "Darkroom mode Green is 0.0")
assertTest(darkroomMult.blue == 0.0, "Darkroom mode Blue is 0.0")

let grayMult = ColorEngine.multipliers(forKelvin: 3400.0, mode: .grayscale)
assertTest(abs(grayMult.red - grayMult.green) < 0.001 && abs(grayMult.green - grayMult.blue) < 0.001, "Grayscale channels are equal")

let ramp = ColorEngine.generateGammaRamp(multiplier: sunsetMult, tableSize: 256)
assertTest(ramp.red.count == 256 && ramp.green.count == 256 && ramp.blue.count == 256, "Gamma ramp table size is 256")
assertTest(ramp.red[0] == 0.0 && ramp.green[0] == 0.0 && ramp.blue[0] == 0.0, "Gamma ramp black point is 0.0")

// MARK: - Solar Engine Tests
print("\n[SolarEngine Tests]")
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
var dateComps = DateComponents()
dateComps.year = 2026
dateComps.month = 6
dateComps.day = 21
dateComps.timeZone = TimeZone(identifier: "America/New_York")

let solsticeDate = calendar.date(from: dateComps)!
let solarTimes = SolarEngine.calculateSolarTimes(
    latitude: 40.7128,
    longitude: -74.0060,
    date: solsticeDate,
    calendar: calendar
)

assertTest(solarTimes.dawn < solarTimes.sunrise, "Dawn precedes sunrise")
assertTest(solarTimes.sunrise < solarTimes.solarNoon, "Sunrise precedes noon")
assertTest(solarTimes.solarNoon < solarTimes.sunset, "Noon precedes sunset")
assertTest(solarTimes.sunset < solarTimes.dusk, "Sunset precedes dusk")

let sunriseHour = calendar.component(.hour, from: solarTimes.sunrise)
let sunsetHour = calendar.component(.hour, from: solarTimes.sunset)
assertTest(sunriseHour == 5, "NYC Summer Solstice sunrise is at 5 AM")
assertTest(sunsetHour == 20, "NYC Summer Solstice sunset is at 8 PM")

let noonResult = SolarEngine.targetKelvin(
    date: solarTimes.solarNoon,
    solarTimes: solarTimes,
    dayKelvin: 6500,
    sunsetKelvin: 3400,
    bedtimeKelvin: 1900,
    wakeHour: 7,
    wakeMinute: 0,
    calendar: calendar
)
assertTest(abs(noonResult.kelvin - 6500.0) < 1.0, "Noon scheduled Kelvin is 6500K")
assertTest(noonResult.phase == .day, "Noon phase is .day")

let sunsetResult = SolarEngine.targetKelvin(
    date: solarTimes.sunset,
    solarTimes: solarTimes,
    dayKelvin: 6500,
    sunsetKelvin: 3400,
    bedtimeKelvin: 1900,
    wakeHour: 7,
    wakeMinute: 0,
    calendar: calendar
)
assertTest(abs(sunsetResult.kelvin - 3400.0) < 1.0, "Sunset scheduled Kelvin is 3400K")

var lateNightComps = dateComps
lateNightComps.hour = 23
lateNightComps.minute = 30
let lateNight = calendar.date(from: lateNightComps)!
let nightResult = SolarEngine.targetKelvin(
    date: lateNight,
    solarTimes: solarTimes,
    dayKelvin: 6500,
    sunsetKelvin: 3400,
    bedtimeKelvin: 1900,
    wakeHour: 7,
    wakeMinute: 0,
    calendar: calendar
)
assertTest(abs(nightResult.kelvin - 1900.0) < 1.0, "Bedtime scheduled Kelvin is 1900K")
assertTest(nightResult.phase == .bedtime, "Bedtime phase is .bedtime")

assertTest(abs(SolarEngine.smoothstep(0.0) - 0.0) < 0.0001, "Smoothstep 0.0 is 0.0")
assertTest(abs(SolarEngine.smoothstep(1.0) - 1.0) < 0.0001, "Smoothstep 1.0 is 1.0")
assertTest(abs(SolarEngine.smoothstep(0.5) - 0.5) < 0.0001, "Smoothstep 0.5 is 0.5")

// MARK: - Disable Manager Tests
print("\n[DisableManager Tests]")
Task { @MainActor in
    let manager = DisableManager.shared
    manager.resume()
    assertTest(!manager.currentState.isPaused, "Initial state is not paused")

    manager.disableForDuration(3600, label: "Disabled for 1 hour")
    assertTest(manager.currentState.isPaused, "1-hour disable sets isPaused to true")

    manager.resume()
    assertTest(!manager.currentState.isPaused, "Resume restores active state")

    manager.toggleManualPause()
    assertTest(manager.currentState.isPaused, "Toggle pause pauses Ember")

    manager.toggleManualPause()
    assertTest(!manager.currentState.isPaused, "Toggle pause resumes Ember")

    let testBundle = "com.test.sampleapp"
    manager.addExcludedApp(bundleID: testBundle)
    assertTest(manager.isAppExcluded(bundleID: testBundle), "Excluded app added")

    manager.removeExcludedApp(bundleID: testBundle)
    assertTest(!manager.isAppExcluded(bundleID: testBundle), "Excluded app removed")

    print("\n-------------------------------------------")
    print("🏁 Results: \(passedCount) passed, \(failedCount) failed.")
    if failedCount > 0 {
        exit(1)
    } else {
        print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
        exit(0)
    }
}

dispatchMain()
