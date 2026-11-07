import Foundation
import SwiftUI
import Combine

/// The central observable application state for Ember.
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    // MARK: - Published Properties

    @Published public var currentKelvin: Double = 6500.0
    @Published public var targetScheduledKelvin: Double = 6500.0
    @Published public var manualSliderOverride: Double? = nil

    @Published public var currentPhase: SolarPhase = .day
    @Published public var solarTimes: SolarTimes
    @Published public var userLocation: UserLocation = .fallback

    @Published public var disableState: DisableState = .active
    @Published public var specialMode: SpecialMode = .none

    // Schedule Preferences
    @Published public var dayKelvin: Double = 6500.0
    @Published public var sunsetKelvin: Double = 3400.0
    @Published public var bedtimeKelvin: Double = 1900.0
    @Published public var wakeHour: Int = 7
    @Published public var wakeMinute: Int = 0
    @Published public var isFastTransition: Bool = false
    @Published public var transitionDurationMinutes: Double = 60.0

    @Published public var activeDisplaysCount: Int = 1

    // Popover Local UI State
    @Published public var popoverSliderValue: Double = 6500.0
    @Published public var isDraggingSlider: Bool = false

    // MARK: - Internal Dependencies

    private let preferences = PreferencesManager.shared
    private let gammaManager = GammaManager.shared
    private let locationManager = LocationManager.shared
    private let disableManager = DisableManager.shared

    private var tickerTimer: DispatchSourceTimer?

    private init() {
        let initialTimes = SolarEngine.calculateSolarTimes(
            latitude: UserLocation.fallback.latitude,
            longitude: UserLocation.fallback.longitude
        )
        self.solarTimes = initialTimes

        loadPreferences()
        setupEngineCallbacks()
        startPeriodicTicker()

        // Initial tick
        recalculateAndApply(animated: false)
    }

    // MARK: - Core Update Cycle

    public func recalculateAndApply(animated: Bool = true) {
        let now = Date()

        // 1. Recalculate astronomical times
        solarTimes = SolarEngine.calculateSolarTimes(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            date: now
        )

        // 2. Evaluate scheduled target Kelvin
        let duration = isFastTransition ? 0.33 : transitionDurationMinutes
        let result = SolarEngine.targetKelvin(
            date: now,
            solarTimes: solarTimes,
            dayKelvin: dayKelvin,
            sunsetKelvin: sunsetKelvin,
            bedtimeKelvin: bedtimeKelvin,
            wakeHour: wakeHour,
            wakeMinute: wakeMinute,
            transitionDurationMinutes: duration
        )
        targetScheduledKelvin = result.kelvin
        currentPhase = result.phase
        activeDisplaysCount = gammaManager.activeDisplayIDs().count

        // 3. Determine effective Kelvin
        let effectiveKelvin: Double
        if let manual = manualSliderOverride {
            effectiveKelvin = manual
        } else {
            effectiveKelvin = targetScheduledKelvin
        }

        if !isDraggingSlider {
            popoverSliderValue = effectiveKelvin
        }

        // 4. Dispatch to hardware GammaManager
        if disableState.isPaused {
            gammaManager.setNeutral(animated: animated)
            currentKelvin = ColorEngine.referenceKelvin
        } else {
            gammaManager.setTemperature(
                kelvin: effectiveKelvin,
                mode: specialMode,
                animated: animated,
                duration: animated ? 0.35 : 0.0
            )
            currentKelvin = effectiveKelvin
        }
    }

    // MARK: - User Intent Actions

    public func setManualSliderPreview(_ kelvin: Double?) {
        manualSliderOverride = kelvin
        recalculateAndApply(animated: false)
    }

    public func setSpecialMode(_ mode: SpecialMode) {
        specialMode = mode
        preferences.specialMode = mode
        recalculateAndApply(animated: true)
    }

    public func disableForOneHour() {
        manualSliderOverride = nil
        disableManager.disableForDuration(3600, label: "Disabled for 1 hour")
    }

    public func disableUntilSunrise() {
        manualSliderOverride = nil
        disableManager.disableUntilSunrise(sunriseDate: solarTimes.sunrise)
    }

    public func togglePause() {
        manualSliderOverride = nil
        disableManager.toggleManualPause()
    }

    public func resume() {
        manualSliderOverride = nil
        disableManager.resume()
    }

    // MARK: - Preferences Management

    public func updateSchedule(day: Double, sunset: Double, bedtime: Double, wakeH: Int, wakeM: Int) {
        dayKelvin = day
        sunsetKelvin = sunset
        bedtimeKelvin = bedtime
        wakeHour = wakeH
        wakeMinute = wakeM

        preferences.dayKelvin = day
        preferences.sunsetKelvin = sunset
        preferences.bedtimeKelvin = bedtime
        preferences.wakeHour = wakeH
        preferences.wakeMinute = wakeM

        recalculateAndApply(animated: true)
    }

    public func setFastTransition(_ fast: Bool) {
        isFastTransition = fast
        preferences.isFastTransition = fast
        recalculateAndApply(animated: true)
    }

    private func loadPreferences() {
        dayKelvin = preferences.dayKelvin
        sunsetKelvin = preferences.sunsetKelvin
        bedtimeKelvin = preferences.bedtimeKelvin
        wakeHour = preferences.wakeHour
        wakeMinute = preferences.wakeMinute
        isFastTransition = preferences.isFastTransition
        transitionDurationMinutes = preferences.transitionDurationMinutes
        specialMode = preferences.specialMode

        if preferences.useManualLocation {
            userLocation = UserLocation(
                latitude: preferences.manualLatitude,
                longitude: preferences.manualLongitude,
                locality: preferences.manualLocality,
                isManual: true
            )
        } else {
            locationManager.enableAutomaticLocation()
            userLocation = locationManager.currentLocation
        }

        disableManager.excludedBundleIdentifiers = Set(preferences.excludedBundleIDs)
    }

    private func setupEngineCallbacks() {
        // Location updates
        locationManager.onLocationChanged = { [weak self] newLoc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.userLocation = newLoc
                self.recalculateAndApply(animated: true)
            }
        }

        // Disable state changes
        disableManager.onStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.disableState = state
                self.recalculateAndApply(animated: true)
            }
        }
    }

    private func startPeriodicTicker() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 15, repeating: .seconds(15))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.recalculateAndApply(animated: true)
            }
        }
        timer.resume()
        tickerTimer = timer
    }
}
