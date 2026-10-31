import SwiftUI

extension MainPage {
    /// What gets remapped, on which devices, and whether that device is in use right now.
    struct TargetSection: View {
        @Environment(StatusViewModel.self) private var status
        @Environment(SettingsViewModel.self) private var settings

        var body: some View {
            @Bindable var settings = settings
            VStack(alignment: .leading, spacing: Spacing.md) {
                ApplySection()
                Picker("Devices", selection: $settings.config.target) {
                    ForEach(DeviceTarget.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .accessibilityIdentifier("main.target")
                TimelineView(.periodic(from: .now, by: Metrics.Main.activityRefresh)) { _ in
                    let active = status.isTargetActive(settings.config.target)
                    Label(active ? "Trackpad in use: remapping" : "Trackpad idle",
                          systemImage: active ? "hand.point.up.left.fill" : "hand.raised.slash")
                        .font(.caption)
                        .foregroundStyle(active ? .green : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
