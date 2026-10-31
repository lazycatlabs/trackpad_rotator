import SwiftUI

@main
struct TrackpadRotatorApp: App {
    @State private var status = StatusViewModel()
    @State private var settings = SettingsViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPage()
                .environment(status)
                .environment(settings)
        } label: {
            Image(systemName: settings.config.enabled ? "rotate.right.fill" : "rotate.right")
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
