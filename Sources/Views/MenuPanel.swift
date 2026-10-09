import SwiftUI

// MARK: - Menu bar panel

struct MenuPanel: View {
    @EnvironmentObject var status: StatusViewModel
    @EnvironmentObject var settings: SettingsViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showPermissions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trackpad Rotator").font(.headline)
                Spacer()
                Toggle("", isOn: $settings.config.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            StatusBanner()
            OrientationControls()
            Divider()
            ApplyControls()
            SpeedControls()
            Divider()
            DisclosureGroup(isExpanded: $showPermissions) {
                PermissionsList().padding(.top, 6)
            } label: {
                Label("Permissions", systemImage: status.allPermissionsGranted
                      ? "checkmark.shield" : "exclamationmark.shield")
            }
            Divider()
            HStack {
                Button("Touch Preview & Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
