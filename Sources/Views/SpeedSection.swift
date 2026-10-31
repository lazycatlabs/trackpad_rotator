import SwiftUI

struct SpeedSection: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Spacing.md) {
            SpeedSlider(title: "Pointer speed", value: $settings.config.pointerSpeed)
                .disabled(!settings.config.applyToPointer)
                .accessibilityIdentifier("speed.pointer")
            SpeedSlider(title: "Scroll speed", value: $settings.config.scrollSpeed)
                .disabled(!settings.config.applyToScroll)
                .accessibilityIdentifier("speed.scroll")
            Text("Applied on top of the Tracking speed in System Settings → Trackpad.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SpeedSlider: View {
    var title: LocalizedStringKey
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2g×", value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    value = 1
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to 1×")
                .opacity(value == 1 ? 0 : 1)
            }
            Slider(value: $value, in: Metrics.Speed.range, step: Metrics.Speed.step) {
                EmptyView()
            } minimumValueLabel: {
                Image(systemName: "tortoise").font(.caption)
            } maximumValueLabel: {
                Image(systemName: "hare").font(.caption)
            }
            .labelsHidden()
        }
    }
}
