import SwiftUI

/// The Touch Preview & Settings window: the live preview on the left, tabbed settings on the right.
/// Tabs keep the window's height fixed as settings are added.
struct MainPage: View {
    @Environment(SettingsViewModel.self) private var settings
    @State private var tab: Tab = .orientation

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
            settingsColumn
        }
        .padding(Spacing.page)
    }

    private var settingsColumn: some View {
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
            Picker("Settings", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("main.tabs")
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.Main.columnSpacing) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Metrics.Main.tabHeight)
        }
        .frame(width: Metrics.Main.settingsWidth)
    }

    @ViewBuilder private var content: some View {
        @Bindable var settings = settings
        switch tab {
        case .orientation:
            GroupBox("Orientation") { OrientationSection().padding(Spacing.sm) }
            GroupBox("Speed") { SpeedSection().padding(Spacing.sm) }
        case .gestures:
            GroupBox("Apply to") { TargetSection().padding(Spacing.sm) }
            GroupBox("Volume & brightness") { EdgeSliderSection().padding(Spacing.sm) }
            Text("System gestures (Mission Control swipes, pinch, rotate) are handled by macOS and are not remapped.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .system:
            GroupBox("Permissions") { PermissionsSection().padding(Spacing.sm) }
            GroupBox("Detected devices") { DevicesSection().padding(Spacing.sm) }
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("main.launchAtLogin")
        case .about:
            GroupBox("About") { AboutSection() }
            SupportSection()
        }
    }
}

extension MainPage {
    enum Tab: String, CaseIterable, Identifiable {
        case orientation, gestures, system, about
        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .orientation: "Orientation"
            case .gestures: "Gestures"
            case .system: "System"
            case .about: "About"
            }
        }
    }
}
