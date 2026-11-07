import Foundation
import AppKit

/// Represents an active temporary disable state.
public enum DisableState: Equatable, Sendable {
    case active
    case disabledUntil(Date, reason: String)
    case pausedForApp(bundleID: String, name: String)
    case pausedManually

    public var isPaused: Bool {
        switch self {
        case .active:
            return false
        case .disabledUntil, .pausedForApp, .pausedManually:
            return true
        }
    }

    public var statusDescription: String {
        switch self {
        case .active:
            return "Active"
        case .disabledUntil(let date, let reason):
            let diff = max(date.timeIntervalSinceNow, 0)
            let mins = Int(diff / 60)
            if mins > 60 {
                let hrs = mins / 60
                let remMins = mins % 60
                return "\(reason) (\(hrs)h \(remMins)m remaining)"
            } else {
                return "\(reason) (\(mins)m remaining)"
            }
        case .pausedForApp(_, let name):
            return "Paused for \(name)"
        case .pausedManually:
            return "Disabled"
        }
    }
}

/// Coordinates quick-disable timers and frontmost application auto-pausing.
@MainActor
public final class DisableManager {
    public static let shared = DisableManager()

    public private(set) var currentState: DisableState = .active
    public var excludedBundleIdentifiers: Set<String> = [
        "com.adobe.Photoshop",
        "com.adobe.Illustrator",
        "com.adobe.LightroomClassicCC",
        "com.figma.Desktop",
        "com.apple.FinalCut",
        "com.apple.Logic10",
        "com.seriflabs.affinityphoto2",
        "com.seriflabs.affinitydesigner2",
        "com.blackmagic-design.DaVinciResolve"
    ]

    public var onStateChanged: ((DisableState) -> Void)?

    private var countdownTimer: DispatchSourceTimer?
    private var workspaceObserver: NSObjectProtocol?

    private init() {
        setupAppSwitchObserver()
    }

    deinit {
        countdownTimer?.cancel()
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Manual & Timed Disables

    /// Disables Ember for a specified duration in seconds (e.g. 3600 for 1 hour).
    public func disableForDuration(_ seconds: TimeInterval, label: String = "Disabled") {
        let untilDate = Date().addingTimeInterval(seconds)
        currentState = .disabledUntil(untilDate, reason: label)
        startCountdownTimer(targetDate: untilDate)
        onStateChanged?(currentState)
    }

    /// Disables Ember until the next sunrise.
    public func disableUntilSunrise(sunriseDate: Date) {
        let target = sunriseDate > Date() ? sunriseDate : Date().addingTimeInterval(8 * 3600)
        currentState = .disabledUntil(target, reason: "Disabled until sunrise")
        startCountdownTimer(targetDate: target)
        onStateChanged?(currentState)
    }

    /// Toggles manual pause on or off.
    public func toggleManualPause() {
        if currentState.isPaused {
            resume()
        } else {
            stopCountdown()
            currentState = .pausedManually
            onStateChanged?(currentState)
        }
    }

    /// Clears any pause or disable, returning to active scheduled state.
    public func resume() {
        stopCountdown()
        currentState = .active
        // Re-check frontmost app in case it is currently excluded
        checkFrontmostApp()
        onStateChanged?(currentState)
    }

    // MARK: - App Exclusions

    public func addExcludedApp(bundleID: String) {
        excludedBundleIdentifiers.insert(bundleID)
        checkFrontmostApp()
    }

    public func removeExcludedApp(bundleID: String) {
        excludedBundleIdentifiers.remove(bundleID)
        if case .pausedForApp(let currentID, _) = currentState, currentID == bundleID {
            resume()
        }
    }

    public func isAppExcluded(bundleID: String) -> Bool {
        return excludedBundleIdentifiers.contains(bundleID)
    }

    private func setupAppSwitchObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFrontmostApp()
            }
        }
        checkFrontmostApp()
    }

    private func checkFrontmostApp() {
        // Do not interrupt timed disables with app pauses
        if case .disabledUntil = currentState { return }
        if case .pausedManually = currentState { return }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            if case .pausedForApp = currentState {
                currentState = .active
                onStateChanged?(currentState)
            }
            return
        }

        let appName = frontApp.localizedName ?? bundleID

        if excludedBundleIdentifiers.contains(bundleID) {
            currentState = .pausedForApp(bundleID: bundleID, name: appName)
            onStateChanged?(currentState)
        } else if case .pausedForApp = currentState {
            currentState = .active
            onStateChanged?(currentState)
        }
    }

    // MARK: - Timer

    private func startCountdownTimer(targetDate: Date) {
        stopCountdown()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(10))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if Date() >= targetDate {
                self.resume()
            } else {
                self.onStateChanged?(self.currentState)
            }
        }
        timer.resume()
        countdownTimer = timer
    }

    private func stopCountdown() {
        countdownTimer?.cancel()
        countdownTimer = nil
    }
}

