import SwiftUI

struct PermissionsSection: View {
    @Environment(StatusViewModel.self) private var status

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Item(title: "Accessibility",
                 detail: "Moves the pointer and rewrites scroll events.",
                 granted: status.accessibilityGranted,
                 request: status.requestAccessibility,
                 openSettings: status.openAccessibilitySettings)
                .accessibilityIdentifier("permissions.accessibility")
            Item(title: "Input Monitoring",
                 detail: "Reads finger data from the trackpad.",
                 granted: status.inputMonitoringGranted,
                 request: status.requestInputMonitoring,
                 openSettings: status.openInputMonitoringSettings)
                .accessibilityIdentifier("permissions.inputMonitoring")
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
