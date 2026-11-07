# 🔥 Ember

> A modern, lightweight, native macOS color temperature utility and f.lux alternative built with Swift, SwiftUI, and hardware CoreGraphics gamma tables.

Ember reduces eye strain and helps maintain circadian rhythms by dynamically warming your display to match the natural solar cycle. At night and bedtime, Ember shifts the screen to warm amber and candlelight tones, eliminating sleep-disrupting blue light directly at the GPU level.

---

## ✨ Features

- **True Hardware Gamma Calibration**: Modifies GPU lookup tables directly via `CGSetDisplayTransferByTable`. No washed-out translucent window overlays, no screenshot discoloration, and no compositor lag.
- **Ultra-Warm Temperature Range**: Smoothly adjusts from **6500K** (neutral daylight) all the way down to **1200K** (deep candlelight).
- **3-Stage Solar Model**:
  - ☀️ **Daytime White** (default 6500K)
  - 🌅 **Sunset / Evening Warmth** (default 3400K)
  - 🌙 **Bedtime Candlelight** (default 1900K, calculated backwards from your wake time)
- **Interactive 24-Hour Solar Timeline**: Visualizes the sun's trajectory with civil dawn, sunrise, solar noon, sunset, dusk, and bedtime, featuring an active glowing indicator at your current time.
- **Quick Disables**:
  - Disable for 1 hour (ideal for quick color checking).
  - Disable until sunrise.
  - One-click pause toggle.
- **Per-App Auto-Pause**: Automatically restores neutral daylight calibration whenever a color-sensitive app (Photoshop, Figma, Final Cut, DaVinci Resolve) is focused.
- **Special Color Modes**:
  - 🔴 **Darkroom Mode**: Complete elimination of green and blue light with enhanced red contrast for night vision and astronomy.
  - 🎬 **Movie Mode**: Softened warming curve designed to preserve deep shadow detail and contrast.
  - 🔘 **Grayscale Mode**: Strips all saturation to minimize screen stimulation and distraction.
- **Astronomical Precision & Location**:
  - Automatic geolocation via macOS `CoreLocation`.
  - Manual City and Coordinate override in Settings.
- **Native macOS Experience**:
  - Built with SwiftUI for macOS 14+ (Sonoma & Sequoia).
  - Dynamic menu bar icon adapting shape and warm tint to your current phase.
  - Pure menu bar agent (`LSUIElement = YES`) with no Dock clutter.
  - Launch at login via Apple `ServiceManagement` (`SMAppService`).
  - Smooth multi-monitor synchronization and instant restore on wake from sleep.

---

## 🏗️ Architecture

```
Ember/
├── Package.swift                    # Swift Package Manager manifest (macOS 14+)
├── Info.plist                       # Bundle metadata (LSUIElement = true)
├── scripts/
│   └── build_app.sh                 # Packaging script creating Ember.app
├── Sources/Ember/
│   ├── EmberApp.swift               # Application entry point & MenuBarExtra
│   ├── Core/
│   │   ├── ColorEngine.swift        # Planckian blackbody locus Kelvin-to-RGB & gamma ramps
│   │   ├── GammaManager.swift       # Direct CoreGraphics display gamma hardware control
│   │   ├── SolarEngine.swift        # NOAA solar ephemeris, twilight, and transition curves
│   │   ├── LocationManager.swift    # CoreLocation manager & reverse geocoding
│   │   └── DisableManager.swift     # Timed disables & frontmost app auto-pause observer
│   ├── Model/
│   │   ├── AppState.swift           # Central @Observable reactive store
│   │   └── PreferencesManager.swift # UserDefaults & Launch-at-Login persistence
│   └── UI/
│       ├── MenuBarView.swift        # Dynamic solar phase icon with warmth tint
│       ├── SolarGraphView.swift     # Interactive 24-hr sinusoidal Canvas curve
│       ├── PopoverView.swift        # Dropdown status, sliders, presets, and quick disables
│       └── SettingsView.swift       # Preferences window (Schedule, Location, Exclusions)
└── Tests/EmberTests/
    ├── ColorEngineTests.swift       # Kelvin math & gamma table tests
    ├── SolarEngineTests.swift       # Astronomical ephemeris & schedule tests
    └── DisableManagerTests.swift    # Disables & app exclusion tests
```

---

## 🚀 Building & Running

### Prerequisites
- macOS 14.0 (Sonoma) or newer.
- Apple Command Line Tools or Xcode (`xcode-select --install`).

### Build and Package
To build the standalone `Ember.app` bundle:
```bash
./scripts/build_app.sh
```

### Run
Launch the application:
```bash
open .build/Ember.app
```

### Run Tests
```bash
swift test
```

---

## 📄 License
MIT License.

