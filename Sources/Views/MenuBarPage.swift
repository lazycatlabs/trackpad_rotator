import SwiftUI

/// The panel that opens from the menu bar icon.
struct MenuBarPage: View {
    @Environment(StatusViewModel.self) private var status
    @Environment(SettingsViewModel.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @State private var showPermissions = false

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Spacing.xl) {
            HStack {
                Text("Trackpad Rotator").font(.headline)
                Spacer()
                Toggle("Enabled", isOn: $settings.config.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityIdentifier("menuBar.enabled")
            }
            StatusBanner()
            OrientationSection()
            Divider()
            ApplySection()
            SpeedSection()
            Divider()
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Volume & brightness").font(.subheadline.weight(.semibold))
                EdgeSliderSection()
            }
            Divider()
            DisclosureGroup(isExpanded: $showPermissions) {
                PermissionsSection().padding(.top, Spacing.sm)
            } label: {
                Label("Permissions", systemImage: status.allPermissionsGranted
                      ? "checkmark.shield" : "exclamationmark.shield")
            }
            Divider()
            HStack {
                Button("Touch Preview & Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .accessibilityIdentifier("menuBar.openMain")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .accessibilityIdentifier("menuBar.quit")
            }
        }
        .padding(Metrics.MenuBar.padding)
        .frame(width: Metrics.MenuBar.width)
    }
}
