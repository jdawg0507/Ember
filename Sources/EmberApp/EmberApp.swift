import SwiftUI
import AppKit
import EmberLib

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        GammaManager.shared.restoreSystemGamma()
    }
}

@main
struct EmberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView(state: appState)
        } label: {
            MenuBarView(state: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(state: appState)
        }
    }
}
