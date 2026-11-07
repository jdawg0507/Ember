import SwiftUI

/// Dynamic menu bar item icon that adapts icon shape and warm tint to solar phase and Kelvin.
public struct MenuBarView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)

            if state.disableState.isPaused {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        if state.disableState.isPaused {
            return "sun.max"
        }

        switch state.specialMode {
        case .darkroom:
            return "moon.fill"
        case .grayscale:
            return "circle.lefthalf.filled"
        case .movie:
            return "film.fill"
        case .none:
            return state.currentPhase.iconName
        }
    }

    private var iconColor: Color {
        if state.disableState.isPaused {
            return .primary.opacity(0.6)
        }

        switch state.specialMode {
        case .darkroom:
            return .red
        case .grayscale:
            return .secondary
        case .movie, .none:
            let k = state.currentKelvin
            if k <= 2200 {
                return Color(red: 1.0, green: 0.45, blue: 0.15)
            } else if k <= 3600 {
                return Color(red: 1.0, green: 0.65, blue: 0.25)
            } else if k <= 5000 {
                return Color(red: 1.0, green: 0.85, blue: 0.5)
            } else {
                return .primary
            }
        }
    }
}
