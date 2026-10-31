import SwiftUI

struct SpeedSection: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Spacing.md) {
            SpeedSlider(identifier: "speed.pointer", title: "Pointer speed", value: $settings.config.pointerSpeed)
                .disabled(!settings.config.applyToPointer)
            SpeedSlider(identifier: "speed.scroll", title: "Scroll speed", value: $settings.config.scrollSpeed)
                .disabled(!settings.config.applyToScroll)
            Text("Applied on top of the Tracking speed in System Settings → Trackpad.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SpeedSlider: View {
    var identifier: String
    var title: LocalizedStringKey
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(0...2))))×")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    value = 1
                } label: {
                    Label("Reset to 1×", systemImage: "arrow.counterclockwise").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Reset to 1×")
                .opacity(value == 1 ? 0 : 1)
                .accessibilityIdentifier("\(identifier).reset")
            }
            Slider(value: $value, in: Metrics.Speed.range, step: Metrics.Speed.step) {
                Text(title)
            } minimumValueLabel: {
                Image(systemName: "tortoise").font(.caption)
            } maximumValueLabel: {
                Image(systemName: "hare").font(.caption)
            }
            .labelsHidden()
            .accessibilityIdentifier("\(identifier).slider")
        }
    }
}
