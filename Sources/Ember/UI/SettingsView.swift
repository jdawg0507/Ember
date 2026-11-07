import SwiftUI
import AppKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var dayKelvin: Double = 6500
    @Published var sunsetKelvin: Double = 3400
    @Published var bedtimeKelvin: Double = 1900
    @Published var wakeDate: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var isFastTransition: Bool = false

    @Published var useManualLocation: Bool = false
    @Published var manualLat: String = ""
    @Published var manualLon: String = ""
    @Published var manualLocality: String = ""

    @Published var newAppBundleID: String = ""
    @Published var excludedApps: [String] = []
    @Published var launchAtLogin: Bool = true

    func load(from state: AppState) {
        dayKelvin = state.dayKelvin
        sunsetKelvin = state.sunsetKelvin
        bedtimeKelvin = state.bedtimeKelvin
        isFastTransition = state.isFastTransition

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = state.wakeHour
        comps.minute = state.wakeMinute
        wakeDate = Calendar.current.date(from: comps) ?? Date()

        useManualLocation = PreferencesManager.shared.useManualLocation
        manualLat = "\(PreferencesManager.shared.manualLatitude)"
        manualLon = "\(PreferencesManager.shared.manualLongitude)"
        manualLocality = PreferencesManager.shared.manualLocality

        excludedApps = PreferencesManager.shared.excludedBundleIDs
        launchAtLogin = PreferencesManager.shared.launchAtLogin
    }

    func commitSchedule(to state: AppState) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: wakeDate)
        state.updateSchedule(
            day: dayKelvin,
            sunset: sunsetKelvin,
            bedtime: bedtimeKelvin,
            wakeH: comps.hour ?? 7,
            wakeM: comps.minute ?? 0
        )
    }

    func addApp() {
        let clean = newAppBundleID.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty && !excludedApps.contains(clean) else { return }
        excludedApps.append(clean)
        PreferencesManager.shared.excludedBundleIDs = excludedApps
        DisableManager.shared.addExcludedApp(bundleID: clean)
        newAppBundleID = ""
    }

    func removeApp(_ id: String) {
        excludedApps.removeAll { $0 == id }
        PreferencesManager.shared.excludedBundleIDs = excludedApps
        DisableManager.shared.removeExcludedApp(bundleID: id)
    }
}

/// Comprehensive macOS Settings preferences window.
public struct SettingsView: View {
    @ObservedObject var state: AppState
    @StateObject private var vm = SettingsViewModel()

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        TabView {
            scheduleTab
                .tabItem {
                    Label("Schedule", systemImage: "clock.badge.checkmark")
                }

            locationTab
                .tabItem {
                    Label("Location", systemImage: "location")
                }

            exclusionsTab
                .tabItem {
                    Label("Exclusions", systemImage: "app.dashed")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 480, height: 360)
        .padding(20)
        .onAppear {
            vm.load(from: state)
        }
    }

    // MARK: - Tabs

    private var scheduleTab: some View {
        Form {
            Section("Color Temperatures") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Daytime White:")
                        Spacer()
                        Text("\(Int(vm.dayKelvin))K").bold()
                    }
                    Slider(value: $vm.dayKelvin, in: 2700...6500, step: 100)
                        .onChange(of: vm.dayKelvin) { _, _ in vm.commitSchedule(to: state) }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sunset / Evening:")
                        Spacer()
                        Text("\(Int(vm.sunsetKelvin))K").bold()
                    }
                    Slider(value: $vm.sunsetKelvin, in: 1900...5500, step: 100)
                        .onChange(of: vm.sunsetKelvin) { _, _ in vm.commitSchedule(to: state) }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Bedtime:")
                        Spacer()
                        Text("\(Int(vm.bedtimeKelvin))K").bold()
                    }
                    Slider(value: $vm.bedtimeKelvin, in: 1200...3400, step: 100)
                        .onChange(of: vm.bedtimeKelvin) { _, _ in vm.commitSchedule(to: state) }
                }
            }

            Section("Sleep Schedule & Transitions") {
                DatePicker("Wake Time:", selection: $vm.wakeDate, displayedComponents: .hourAndMinute)
                    .onChange(of: vm.wakeDate) { _, _ in vm.commitSchedule(to: state) }

                Toggle("Fast Transitions (20s instead of 60m)", isOn: $vm.isFastTransition)
                    .onChange(of: vm.isFastTransition) { _, newVal in
                        state.setFastTransition(newVal)
                    }
            }
        }
    }

    private var locationTab: some View {
        Form {
            Section("Location Mode") {
                Toggle("Set Coordinates Manually", isOn: $vm.useManualLocation)
                    .onChange(of: vm.useManualLocation) { _, isManual in
                        PreferencesManager.shared.useManualLocation = isManual
                        if !isManual {
                            LocationManager.shared.enableAutomaticLocation()
                        }
                    }

                if vm.useManualLocation {
                    TextField("City / Locality:", text: $vm.manualLocality)
                    TextField("Latitude:", text: $vm.manualLat)
                    TextField("Longitude:", text: $vm.manualLon)

                    Button("Save Location") {
                        if let lat = Double(vm.manualLat), let lon = Double(vm.manualLon) {
                            PreferencesManager.shared.manualLatitude = lat
                            PreferencesManager.shared.manualLongitude = lon
                            PreferencesManager.shared.manualLocality = vm.manualLocality
                            LocationManager.shared.setManualLocation(latitude: lat, longitude: lon, locality: vm.manualLocality)
                        }
                    }
                } else {
                    LabeledContent("Detected Location:", value: state.userLocation.locality)
                    LabeledContent("Coordinates:", value: String(format: "%.4f, %.4f", state.userLocation.latitude, state.userLocation.longitude))

                    Button("Re-detect Location") {
                        LocationManager.shared.enableAutomaticLocation()
                    }
                }
            }
        }
    }

    private var exclusionsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auto-Pause for Color-Sensitive Apps")
                .font(.headline)

            Text("Ember automatically restores normal daylight calibration when any of these applications are frontmost.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(vm.excludedApps, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            vm.removeApp(bundleID)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 140)

            HStack {
                TextField("Add bundle ID (e.g. com.figma.Desktop)", text: $vm.newAppBundleID)
                Button("Add") {
                    vm.addApp()
                }
                .disabled(vm.newAppBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Ember at Login", isOn: $vm.launchAtLogin)
                    .onChange(of: vm.launchAtLogin) { _, newVal in
                        PreferencesManager.shared.launchAtLogin = newVal
                    }
            }

            Section("Hardware Displays") {
                LabeledContent("Active Screens Connected:", value: "\(state.activeDisplaysCount)")
            }

            Section("Reset") {
                Button("Reset All Settings to Factory Defaults", role: .destructive) {
                    PreferencesManager.shared.resetToDefaults()
                    vm.load(from: state)
                    state.recalculateAndApply(animated: true)
                }
            }
        }
    }
}
