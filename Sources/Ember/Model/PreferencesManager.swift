import Foundation
import ServiceManagement

/// Manages persistent user preferences with sensible defaults.
@MainActor
public final class PreferencesManager {
    public static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let dayKelvin = "dayKelvin"
        static let sunsetKelvin = "sunsetKelvin"
        static let bedtimeKelvin = "bedtimeKelvin"
        static let wakeHour = "wakeHour"
        static let wakeMinute = "wakeMinute"
        static let transitionDurationMinutes = "transitionDurationMinutes"
        static let isFastTransition = "isFastTransition"
        static let launchAtLogin = "launchAtLogin"
        static let manualLatitude = "manualLatitude"
        static let manualLongitude = "manualLongitude"
        static let manualLocality = "manualLocality"
        static let useManualLocation = "useManualLocation"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let specialMode = "specialMode"
    }

    public var dayKelvin: Double {
        get { defaults.object(forKey: Keys.dayKelvin) as? Double ?? 6500.0 }
        set { defaults.set(newValue, forKey: Keys.dayKelvin) }
    }

    public var sunsetKelvin: Double {
        get { defaults.object(forKey: Keys.sunsetKelvin) as? Double ?? 3400.0 }
        set { defaults.set(newValue, forKey: Keys.sunsetKelvin) }
    }

    public var bedtimeKelvin: Double {
        get { defaults.object(forKey: Keys.bedtimeKelvin) as? Double ?? 1900.0 }
        set { defaults.set(newValue, forKey: Keys.bedtimeKelvin) }
    }

    public var wakeHour: Int {
        get { defaults.object(forKey: Keys.wakeHour) as? Int ?? 7 }
        set { defaults.set(newValue, forKey: Keys.wakeHour) }
    }

    public var wakeMinute: Int {
        get { defaults.object(forKey: Keys.wakeMinute) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Keys.wakeMinute) }
    }

    public var transitionDurationMinutes: Double {
        get { defaults.object(forKey: Keys.transitionDurationMinutes) as? Double ?? 60.0 }
        set { defaults.set(newValue, forKey: Keys.transitionDurationMinutes) }
    }

    public var isFastTransition: Bool {
        get { defaults.bool(forKey: Keys.isFastTransition) }
        set { defaults.set(newValue, forKey: Keys.isFastTransition) }
    }

    public var manualLatitude: Double {
        get { defaults.object(forKey: Keys.manualLatitude) as? Double ?? 40.7128 }
        set { defaults.set(newValue, forKey: Keys.manualLatitude) }
    }

    public var manualLongitude: Double {
        get { defaults.object(forKey: Keys.manualLongitude) as? Double ?? -74.0060 }
        set { defaults.set(newValue, forKey: Keys.manualLongitude) }
    }

    public var manualLocality: String {
        get { defaults.string(forKey: Keys.manualLocality) ?? "New York, USA" }
        set { defaults.set(newValue, forKey: Keys.manualLocality) }
    }

    public var useManualLocation: Bool {
        get { defaults.bool(forKey: Keys.useManualLocation) }
        set { defaults.set(newValue, forKey: Keys.useManualLocation) }
    }

    public var excludedBundleIDs: [String] {
        get {
            defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? [
                "com.adobe.Photoshop",
                "com.figma.Desktop",
                "com.apple.FinalCut",
                "com.seriflabs.affinityphoto2"
            ]
        }
        set { defaults.set(newValue, forKey: Keys.excludedBundleIDs) }
    }

    public var specialMode: SpecialMode {
        get {
            guard let raw = defaults.string(forKey: Keys.specialMode),
                  let mode = SpecialMode(rawValue: raw) else {
                return .none
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.specialMode) }
    }

    public var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // ServiceManagement registration logged or ignored if not packaged
                }
            }
        }
    }

    /// Resets all settings to factory defaults.
    public func resetToDefaults() {
        dayKelvin = 6500.0
        sunsetKelvin = 3400.0
        bedtimeKelvin = 1900.0
        wakeHour = 7
        wakeMinute = 0
        transitionDurationMinutes = 60.0
        isFastTransition = false
        useManualLocation = false
        specialMode = .none
        excludedBundleIDs = [
            "com.adobe.Photoshop",
            "com.figma.Desktop",
            "com.apple.FinalCut",
            "com.seriflabs.affinityphoto2"
        ]
    }
}

