import SwiftUI

extension PermissionsSection {
    /// One permission: whether it's granted, and a button to ask for it or open its settings.
    struct Item: View {
        var title: String
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
}
