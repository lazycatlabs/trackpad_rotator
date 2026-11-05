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

    private var snapped: Binding<Double> {
        Binding(get: { value }, set: { set($0) })
    }

    /// Rounds to a step and keeps it in range.
    private func set(_ new: Double) {
        let r = Metrics.Speed.range
        value = min(max((new / Metrics.Speed.step).rounded() / (1 / Metrics.Speed.step), r.lowerBound), r.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(0...2))))×")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(identifier).value")
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
            HStack {
                stepButton("Slower", systemImage: "tortoise", by: -Metrics.Speed.step, id: "decrease")
                Slider(value: snapped, in: Metrics.Speed.range) {
                    Text(title)
                }
                .labelsHidden()
                .accessibilityIdentifier("\(identifier).slider")
                stepButton("Faster", systemImage: "hare", by: Metrics.Speed.step, id: "increase")
            }
        }
    }

    private func stepButton(_ label: LocalizedStringKey, systemImage: String, by step: Double, id: String) -> some View {
        Button {
            set(value + step)
        } label: {
            Label(label, systemImage: systemImage).labelStyle(.iconOnly).font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(label)
        .accessibilityIdentifier("\(identifier).\(id)")
    }
}
