import SwiftUI

// MARK: - Main window

struct MainWindow: View {
    @EnvironmentObject var status: StatusViewModel
    @EnvironmentObject var settings: SettingsViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                TouchPreview(transform: settings.config.transform, target: settings.config.target)
                Text("Put your fingers on the trackpad. The left pad shows the raw touch points the trackpad reports; the right pad shows them after your orientation and X/Y settings. When it's right, moving your finger \u{201C}up\u{201D} makes the dot on the right move up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 520, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Toggle("Enabled", isOn: $settings.config.enabled)
                        .toggleStyle(.switch)
                        .font(.headline)
                    Spacer()
                    Button("Reset X/Y") { settings.resetAxes() }
                        .controlSize(.small)
                }
                StatusBanner()
                GroupBox("Orientation") {
                    OrientationControls().padding(6)
                }
                GroupBox("Apply to") {
                    VStack(alignment: .leading, spacing: 8) {
                        ApplyControls()
                        Picker("Devices", selection: $settings.config.target) {
                            ForEach(DeviceTarget.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                            let active = status.isTargetActive(settings.config.target)
                            Label(active ? "Trackpad in use: remapping" : "Trackpad idle",
                                  systemImage: active ? "hand.point.up.left.fill" : "hand.raised.slash")
                                .font(.caption)
                                .foregroundStyle(active ? .green : .secondary)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Speed") {
                    SpeedControls().padding(6)
                }
                GroupBox("Permissions") {
                    PermissionsList().padding(6)
                }
                GroupBox("Detected devices") {
                    VStack(alignment: .leading, spacing: 4) {
                        if status.devices.isEmpty {
                            Text("None found").foregroundStyle(.secondary)
                        }
                        ForEach(status.devices) { d in
                            HStack {
                                Image(systemName: d.matches(settings.config.target) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(d.matches(settings.config.target) ? .green : .secondary)
                                Text(d.name)
                                Spacer()
                                if d.info.width > 0 {
                                    Text(String(format: "%.0f×%.0f mm", d.widthMM, d.heightMM))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.callout)
                        }
                        Button("Rescan") { status.rescanDevices() }
                            .controlSize(.small)
                            .padding(.top, 4)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.checkbox)
                Text("System gestures (Mission Control swipes, pinch, rotate) are handled by macOS and are not remapped.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 320)
        }
        .padding(20)
    }
}

private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
}
