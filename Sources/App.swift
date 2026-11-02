import SwiftUI

@main
struct TrackpadRotatorApp: App {
    @State private var status = StatusViewModel()
    @State private var settings = SettingsViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarPage()
                .environment(status)
                .environment(settings)
        } label: {
            Image(systemName: settings.config.enabled ? "rotate.right.fill" : "rotate.right")
                // UI tests can't click the menu bar icon, so the window opens at launch for them.
                .task { if isUITesting { openWindow(id: "main") } }
        }
        .menuBarExtraStyle(.window)

        Window("Trackpad Rotator", id: "main") {
            MainPage()
                .environment(status)
                .environment(settings)
        }
        .windowResizability(.contentSize)
    }
}
