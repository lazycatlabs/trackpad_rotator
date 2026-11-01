import SwiftUI

/// Volume and brightness from the trackpad's edges, turned on per kind of trackpad.
struct EdgeSliderSection: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xxl) {
                Toggle("Built‑in trackpad", isOn: $settings.config.edgeSlidersBuiltIn)
                    .accessibilityIdentifier("edgeSliders.builtIn")
                Toggle("Magic Trackpad", isOn: $settings.config.edgeSlidersExternal)
                    .accessibilityIdentifier("edgeSliders.external")
            }
            .toggleStyle(.checkbox)
            Toggle("Haptic feedback on each step", isOn: $settings.config.edgeSliderHaptics)
                .toggleStyle(.checkbox)
                .disabled(!settings.config.edgeSlidersBuiltIn && !settings.config.edgeSlidersExternal)
                .accessibilityIdentifier("edgeSliders.haptics")
            Text("Slide one finger up or down along your left edge for brightness, or your right edge for volume.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
