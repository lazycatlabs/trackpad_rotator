import SwiftUI

extension MainPage {
    struct DevicesSection: View {
        @Environment(StatusViewModel.self) private var status
        @Environment(SettingsViewModel.self) private var settings

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if status.devices.isEmpty {
                    DevicesEmpty()
                }
                ForEach(status.devices) { DeviceItem(device: $0, target: settings.config.target) }
                Button("Rescan") { status.rescanDevices() }
                    .controlSize(.small)
                    .padding(.top, Spacing.xs)
                    .accessibilityIdentifier("devices.rescan")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One detected trackpad or mouse, ticked when the current target includes it.
    struct DeviceItem: View {
        var device: DeviceSnapshot
        var target: DeviceTarget

        var body: some View {
            let matches = device.matches(target)
            HStack {
                Image(systemName: matches ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(matches ? .green : .secondary)
                Text(device.name)
                Spacer()
                if device.info.width > 0, device.info.height > 0 {
                    Text(String(format: "%.0f×%.0f mm", device.widthMM, device.heightMM))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    struct DevicesEmpty: View {
        var body: some View {
            Text("None found").foregroundStyle(.secondary)
        }
    }
}
