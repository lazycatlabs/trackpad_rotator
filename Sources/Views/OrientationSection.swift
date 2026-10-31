import SwiftUI

struct OrientationSection: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Picker("Orientation", selection: $settings.config.transform.rotation) {
                ForEach(Rotation.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("orientation.rotation")

            Text(settings.config.transform.rotation.longLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Touch point axes").font(.subheadline.weight(.semibold))
            HStack(spacing: Spacing.xxl) {
                Toggle("Swap X ↔ Y", isOn: $settings.config.transform.swapXY)
                    .accessibilityIdentifier("orientation.swapXY")
                Toggle("Invert X", isOn: $settings.config.transform.invertX)
                    .accessibilityIdentifier("orientation.invertX")
                Toggle("Invert Y", isOn: $settings.config.transform.invertY)
                    .accessibilityIdentifier("orientation.invertY")
            }
            .toggleStyle(.checkbox)
        }
    }
}
