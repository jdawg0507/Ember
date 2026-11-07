import SwiftUI

/// Main popover window presented when the menu bar item is clicked.
public struct PopoverView: View {
    @ObservedObject var state: AppState
    @Environment(\.openSettings) private var openSettings

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 14) {
            // MARK: - Header Status Banner
            headerView

            // MARK: - 24-Hour Solar Timeline Curve
            SolarGraphView(
                solarTimes: state.solarTimes,
                currentKelvin: state.currentKelvin,
                currentPhase: state.currentPhase
            )

            // MARK: - Color Temperature Slider
            temperatureSliderSection

            // MARK: - Quick Temperature Presets
            presetsSection

            Divider()

            // MARK: - Quick Disables & Special Modes
            actionsSection

            Divider()

            // MARK: - Footer (Location, Settings, Quit)
            footerView
        }
        .padding(14)
        .frame(width: 320)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(statusHeadline)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Text(statusSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                state.togglePause()
            } label: {
                Image(systemName: state.disableState.isPaused ? "play.circle.fill" : "pause.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(state.disableState.isPaused ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(state.disableState.isPaused ? "Resume Ember" : "Pause Ember")
        }
    }

    private var temperatureSliderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Color Temperature")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if state.manualSliderOverride != nil {
                    Button("Reset to Schedule") {
                        state.setManualSliderPreview(nil)
                        state.popoverSliderValue = state.targetScheduledKelvin
                    }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.borderless)
                }

                Text("\(Int(state.popoverSliderValue))K")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(temperatureColor(state.popoverSliderValue))
            }

            Slider(
                value: Binding(
                    get: { state.popoverSliderValue },
                    set: { newVal in
                        state.popoverSliderValue = newVal
                        state.isDraggingSlider = true
                        state.setManualSliderPreview(newVal)
                    }
                ),
                in: 1200...6500,
                step: 50
            ) { editing in
                state.isDraggingSlider = editing
            }
            .tint(temperatureColor(state.popoverSliderValue))
        }
    }

    private var presetsSection: some View {
        HStack(spacing: 6) {
            presetButton(title: "Day", kelvin: state.dayKelvin, icon: "sun.max.fill")
            presetButton(title: "Sunset", kelvin: state.sunsetKelvin, icon: "sunset.fill")
            presetButton(title: "Bedtime", kelvin: state.bedtimeKelvin, icon: "moon.stars.fill")
            presetButton(title: "Candle", kelvin: 1200, icon: "flame.fill")
        }
    }

    private func presetButton(title: String, kelvin: Double, icon: String) -> some View {
        Button {
            state.popoverSliderValue = kelvin
            state.setManualSliderPreview(kelvin)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(temperatureColor(kelvin))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    state.disableForOneHour()
                } label: {
                    Label("1 Hour", systemImage: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .disabled(state.disableState.isPaused)

                Button {
                    state.disableUntilSunrise()
                } label: {
                    Label("Until Sunrise", systemImage: "sunrise")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .disabled(state.disableState.isPaused)
            }

            // Mode Selector
            HStack {
                Text("Mode:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { state.specialMode },
                    set: { state.setSpecialMode($0) }
                )) {
                    ForEach(SpecialMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var footerView: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Text(state.userLocation.locality.isEmpty ? "Local Area" : state.userLocation.locality)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Open Preferences")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Quit Ember")
        }
    }

    // MARK: - Helpers

    private var statusHeadline: String {
        if state.disableState.isPaused {
            return state.disableState.statusDescription
        }

        switch state.specialMode {
        case .darkroom:
            return "Darkroom Mode"
        case .grayscale:
            return "Grayscale Active"
        case .movie:
            return "Movie Mode"
        case .none:
            return state.currentPhase.rawValue
        }
    }

    private var statusSubtitle: String {
        if state.disableState.isPaused {
            return "Display calibrated to neutral 6500K"
        }

        let now = Date()
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated

        if now < state.solarTimes.sunset {
            let interval = state.solarTimes.sunset.timeIntervalSince(now)
            let timeStr = formatter.string(from: interval) ?? ""
            return "Sunset in \(timeStr) • Target \(Int(state.targetScheduledKelvin))K"
        } else if now < state.solarTimes.sunrise {
            let interval = state.solarTimes.sunrise.timeIntervalSince(now)
            let timeStr = formatter.string(from: interval) ?? ""
            return "Sunrise in \(timeStr) • Target \(Int(state.targetScheduledKelvin))K"
        } else {
            return "Target \(Int(state.targetScheduledKelvin))K"
        }
    }

    private func temperatureColor(_ kelvin: Double) -> Color {
        if kelvin <= 2200 {
            return Color(red: 1.0, green: 0.35, blue: 0.1)
        } else if kelvin <= 3600 {
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        } else if kelvin <= 5000 {
            return Color(red: 1.0, green: 0.8, blue: 0.45)
        } else {
            return .primary
        }
    }
}
