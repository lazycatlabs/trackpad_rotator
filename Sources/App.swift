import SwiftUI

@main
struct TrackpadRotatorApp: App {
    @StateObject private var status = StatusViewModel()
    @StateObject private var settings = SettingsViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environmentObject(status)
                .environmentObject(settings)
        } label: {
            Image(systemName: settings.config.enabled ? "rotate.right.fill" : "rotate.right")
        }
        .menuBarExtraStyle(.window)

        Window("Trackpad Rotator", id: "main") {
            MainWindow()
                .environmentObject(status)
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
    }
}
