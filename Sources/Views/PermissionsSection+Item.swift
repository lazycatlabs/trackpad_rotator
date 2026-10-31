import SwiftUI

extension PermissionsSection {
    /// One permission: whether it's granted, and a button to ask for it or open its settings.
    struct Item: View {
        var identifier: String
        var title: LocalizedStringKey
        var detail: LocalizedStringKey
        var granted: Bool
        var request: () -> Void
        var openSettings: () -> Void

        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
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
                        .help("Open this permission in System Settings")
                        .accessibilityIdentifier("\(identifier).settings")
                } else {
                    Button("Request") { request() }
                        .controlSize(.small)
                        .help("Ask macOS for this permission, or open System Settings if it was already asked")
                        .accessibilityIdentifier("\(identifier).request")
                }
            }
            .font(.callout)
        }
    }
}
