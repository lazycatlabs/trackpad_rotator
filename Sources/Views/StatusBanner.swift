import SwiftUI

/// The first thing that stops the app from working: a missing permission or the multitouch framework.
struct StatusBanner: View {
    @Environment(StatusViewModel.self) private var status

    var body: some View {
        if !status.accessibilityGranted {
            Warning(identifier: "statusBanner.accessibility",
                    title: "Accessibility permission needed",
                    detail: "Turn on Trackpad Rotator in System Settings → Privacy & Security → Accessibility so it can remap the pointer.",
                    action: "Open Accessibility Settings",
                    open: status.openAccessibilitySettings)
        } else if !status.inputMonitoringGranted {
            Warning(identifier: "statusBanner.inputMonitoring",
                    title: "Input Monitoring permission needed",
                    detail: "Turn on Trackpad Rotator in System Settings → Privacy & Security → Input Monitoring so it can tell when your fingers are on the Magic Trackpad.",
                    action: "Open Input Monitoring Settings",
                    open: status.openInputMonitoringSettings)
        } else if !status.multitouchAvailable {
            Label("Multitouch framework unavailable: can't tell trackpad from mouse.", systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("statusBanner.multitouch")
        }
    }
}

private struct Warning: View {
    var identifier: String
    var title: LocalizedStringKey
    var detail: LocalizedStringKey
    var action: LocalizedStringKey
    var open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action, action: open)
                .controlSize(.small)
                .accessibilityIdentifier("\(identifier).open")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(Opacity.fill), in: RoundedRectangle(cornerRadius: Radius.md))
    }
}
