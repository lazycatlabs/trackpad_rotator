import SwiftUI

/// The Touch Preview & Settings window.
struct MainPage: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.page) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                TouchPreviewSection(transform: settings.config.transform, target: settings.config.target)
                Text("Put your fingers on the trackpad. The left pad shows the raw touch points the trackpad reports; the right pad shows them after your orientation and X/Y settings. When it's right, moving your finger \u{201C}up\u{201D} makes the dot on the right move up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: Metrics.Main.previewCaptionWidth, alignment: .leading)
            }
            sidebar
        }
        .padding(Spacing.page)
    }

    private var sidebar: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: Metrics.Main.columnSpacing) {
            HStack {
                Toggle("Enabled", isOn: $settings.config.enabled)
                    .toggleStyle(.switch)
                    .font(.headline)
                    .accessibilityIdentifier("main.enabled")
                Spacer()
                Button("Reset X/Y") { settings.resetAxes() }
                    .controlSize(.small)
                    .accessibilityIdentifier("main.resetAxes")
            }
            StatusBanner()
            GroupBox("Orientation") { OrientationSection().padding(Spacing.sm) }
            GroupBox("Apply to") { TargetSection().padding(Spacing.sm) }
            GroupBox("Speed") { SpeedSection().padding(Spacing.sm) }
            GroupBox("Permissions") { PermissionsSection().padding(Spacing.sm) }
            GroupBox("Detected devices") { DevicesSection().padding(Spacing.sm) }
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("main.launchAtLogin")
            Text("System gestures (Mission Control swipes, pinch, rotate) are handled by macOS and are not remapped.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GroupBox("About") { AboutSection() }
        }
        .frame(width: Metrics.Main.sidebarWidth)
    }
}
