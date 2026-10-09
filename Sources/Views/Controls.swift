import SwiftUI

// MARK: - Shared controls

struct StatusBanner: View {
    @Environment(StatusViewModel.self) private var status

    var body: some View {
        if !status.accessibilityGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Accessibility permission needed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout.weight(.semibold))
                Text("Turn on Trackpad Rotator in System Settings → Privacy & Security → Accessibility so it can remap the pointer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") { status.openAccessibilitySettings() }
                    .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else if !status.inputMonitoringGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Input Monitoring permission needed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout.weight(.semibold))
                Text("Turn on Trackpad Rotator in System Settings → Privacy & Security → Input Monitoring so it can tell when your fingers are on the Magic Trackpad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Input Monitoring Settings") { status.openInputMonitoringSettings() }
                    .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else if !status.multitouchAvailable {
            Label("Multitouch framework unavailable: can't tell trackpad from mouse.", systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

struct PermissionsList: View {
    @Environment(StatusViewModel.self) private var status

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PermissionRow(title: "Accessibility",
                          detail: "Moves the pointer and rewrites scroll events.",
                          granted: status.accessibilityGranted,
                          request: status.requestAccessibility,
                          openSettings: status.openAccessibilitySettings)
            PermissionRow(title: "Input Monitoring",
                          detail: "Reads finger data from the trackpad.",
                          granted: status.inputMonitoringGranted,
                          request: status.requestInputMonitoring,
                          openSettings: status.openInputMonitoringSettings)
            HStack {
                Text(status.allPermissionsGranted
                     ? "All permissions granted."
                     : "Checked automatically every 2 seconds.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check Again") { status.refresh() }
                    .controlSize(.small)
            }
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var detail: String
    var granted: Bool
    var request: () -> Void
    var openSettings: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Button("Settings") { openSettings() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Open \(title) in System Settings")
            } else {
                Button("Request") { request() }
                    .controlSize(.small)
                    .help("Ask macOS for \(title) access, or open System Settings if it was already asked")
            }
        }
        .font(.callout)
    }
}

struct OrientationControls: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 10) {
            Picker("Orientation", selection: $settings.config.transform.rotation) {
                ForEach(Rotation.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)

            Text(settings.config.transform.rotation.longLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Touch point axes").font(.subheadline.weight(.semibold))
            HStack(spacing: 16) {
                Toggle("Swap X ↔ Y", isOn: $settings.config.transform.swapXY)
                Toggle("Invert X", isOn: $settings.config.transform.invertX)
                Toggle("Invert Y", isOn: $settings.config.transform.invertY)
            }
            .toggleStyle(.checkbox)
        }
    }
}

struct ApplyControls: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Remap pointer movement", isOn: $settings.config.applyToPointer)
            Toggle("Remap two‑finger scrolling", isOn: $settings.config.applyToScroll)
            Toggle("Swipe between pages (back/forward)", isOn: $settings.config.swipeNavigation)
                .disabled(!settings.config.applyToScroll)
            Toggle("Right‑edge swipe opens Notification Center", isOn: $settings.config.notificationCenterSwipe)
            Toggle("Three‑ and four‑finger swipes", isOn: $settings.config.dockSwipes)
        }
        .toggleStyle(.checkbox)
    }
}

struct SpeedControls: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 8) {
            SpeedSlider(title: "Pointer speed", value: $settings.config.pointerSpeed)
                .disabled(!settings.config.applyToPointer)
            SpeedSlider(title: "Scroll speed", value: $settings.config.scrollSpeed)
                .disabled(!settings.config.applyToScroll)
            Text("Applied on top of the Tracking speed in System Settings → Trackpad.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SpeedSlider: View {
    var title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
            Slider(value: $value, in: 0.25...3, step: 0.05) {
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
