import SwiftUI

struct PermissionsSection: View {
    @Environment(StatusViewModel.self) private var status

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Item(identifier: "permissions.accessibility",
                 title: "Accessibility",
                 detail: "Moves the pointer and rewrites scroll events.",
                 granted: status.accessibilityGranted,
                 request: status.requestAccessibility,
                 openSettings: status.openAccessibilitySettings)
            Item(identifier: "permissions.inputMonitoring",
                 title: "Input Monitoring",
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
                    .accessibilityIdentifier("permissions.checkAgain")
            }
        }
    }
}
