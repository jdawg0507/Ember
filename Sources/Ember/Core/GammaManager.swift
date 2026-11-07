import Foundation
import CoreGraphics
import AppKit

/// Manages hardware display gamma tables across all connected screens.
@MainActor
public final class GammaManager {
    public static let shared = GammaManager()

    /// Gamma ramp table size used for CoreGraphics hardware transfers.
    private let tableSize: Int = 256

    /// Currently applied target Kelvin color temperature.
    public private(set) var currentKelvin: Double = ColorEngine.referenceKelvin

    /// Active special mode (e.g., standard, darkroom, movie, grayscale).
    public private(set) var currentMode: SpecialMode = .none

    /// Whether Ember is actively applying custom gamma (or paused/neutral).
    public private(set) var isEnabled: Bool = true

    /// Animation timer for smooth 60 Hz transitions between temperatures.
    private var animationTimer: DispatchSourceTimer?
    private var animatedStartKelvin: Double = ColorEngine.referenceKelvin
    private var animatedTargetKelvin: Double = ColorEngine.referenceKelvin
    private var animationStartTime: CFTimeInterval = 0
    private var animationDuration: CFTimeInterval = 0.3

    /// Display reconfiguration callback registration token.
    private var isRegisteredForDisplayEvents = false

    private init() {
        setupDisplayListeners()
    }

    // MARK: - Gamma Control

    /// Applies a target color temperature and mode, smoothly animating from the current state.
    public func setTemperature(
        kelvin: Double,
        mode: SpecialMode = .none,
        animated: Bool = true,
        duration: CFTimeInterval = 0.35
    ) {
        guard isEnabled else { return }

        let clampedKelvin = min(max(kelvin, ColorEngine.minimumKelvin), ColorEngine.maximumKelvin)

        if !animated || duration <= 0.05 {
            stopAnimation()
            currentKelvin = clampedKelvin
            currentMode = mode
            applyHardwareGamma(kelvin: clampedKelvin, mode: mode)
            return
        }

        // Setup smooth animation
        stopAnimation()
        animatedStartKelvin = currentKelvin
        animatedTargetKelvin = clampedKelvin
        currentMode = mode
        animationStartTime = CACurrentMediaTime()
        animationDuration = duration

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16)) // ~60 fps
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let elapsed = CACurrentMediaTime() - self.animationStartTime
            let progress = min(max(elapsed / self.animationDuration, 0.0), 1.0)
            let smoothed = SolarEngine.smoothstep(progress)

            let interpolatedKelvin = SolarEngine.lerp(
                from: self.animatedStartKelvin,
                to: self.animatedTargetKelvin,
                t: smoothed
            )
            self.currentKelvin = interpolatedKelvin
            self.applyHardwareGamma(kelvin: interpolatedKelvin, mode: self.currentMode)

            if progress >= 1.0 {
                self.stopAnimation()
            }
        }
        timer.resume()
        animationTimer = timer
    }

    /// Immediately pauses custom gamma, restoring default neutral system calibration (6500K).
    public func setNeutral(animated: Bool = true, duration: CFTimeInterval = 0.4) {
        if animated {
            setTemperature(kelvin: ColorEngine.referenceKelvin, mode: .none, animated: true, duration: duration)
        } else {
            stopAnimation()
            currentKelvin = ColorEngine.referenceKelvin
            currentMode = .none
            applyHardwareGamma(kelvin: ColorEngine.referenceKelvin, mode: .none)
        }
    }

    /// Completely restores macOS system ColorSync hardware calibration across all screens.
    public static func restoreSystemGamma() {
        CGDisplayRestoreColorSyncSettings()
    }

    /// Instance method restoring macOS system ColorSync hardware calibration.
    public func restoreSystemGamma() {
        stopAnimation()
        Self.restoreSystemGamma()
    }

    /// Re-applies the current temperature to all screens (useful after wake or display connect).
    public func refreshDisplays() {
        applyHardwareGamma(kelvin: currentKelvin, mode: currentMode)
    }

    // MARK: - Hardware Application

    private func applyHardwareGamma(kelvin: Double, mode: SpecialMode) {
        let multipliers = ColorEngine.multipliers(forKelvin: kelvin, mode: mode)
        var ramp = ColorEngine.generateGammaRamp(
            multiplier: multipliers,
            mode: mode,
            tableSize: tableSize
        )

        let displays = activeDisplayIDs()
        let count = UInt32(tableSize)

        for displayID in displays {
            CGSetDisplayTransferByTable(
                displayID,
                count,
                &ramp.red,
                &ramp.green,
                &ramp.blue
            )
        }
    }

    /// Returns list of all currently active macOS display IDs.
    public func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return [CGMainDisplayID()]
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let result = CGGetActiveDisplayList(count, &displays, &count)
        guard result == .success else {
            return [CGMainDisplayID()]
        }
        return Array(displays.prefix(Int(count)))
    }

    private func stopAnimation() {
        animationTimer?.cancel()
        animationTimer = nil
    }

    // MARK: - System Observers

    private func setupDisplayListeners() {
        // Observe Mac wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Delay slightly for display drivers to re-initialize
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.refreshDisplays()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                self?.refreshDisplays()
            }
        }

        // Register display reconfiguration callback
        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            guard flags.contains(.addFlag) || flags.contains(.enabledFlag) else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                GammaManager.shared.refreshDisplays()
            }
        }, nil)
    }
}
