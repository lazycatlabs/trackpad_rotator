import SwiftUI

private let supportEmail = "admin@lazycatlabs.com"
private let website = URL(string: "https://trackpadrotator.lazycatlabs.com/")!

extension MainPage {
    /// Version, update check, What's New, and the feedback links.
    struct AboutSection: View {
        @State private var updates = UpdateChecker()
        @State private var showWhatsNew = false

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Trackpad Rotator v\(appVersion)").font(.callout)
                    Spacer()
                    Button("What's New", systemImage: "sparkles") { showWhatsNew = true }
                        .controlSize(.small)
                        .accessibilityIdentifier("about.whatsNew")
                }
                updateRow
                Divider()
                HStack {
                    Button("Feedback", systemImage: "bubble.left") { mail("Trackpad Rotator Feedback") }
                        .accessibilityIdentifier("about.feedback")
                    Button("Report Bug", systemImage: "ladybug") { mail("Trackpad Rotator Bug Report", body: bugTemplate) }
                        .accessibilityIdentifier("about.reportBug")
                    Button("Website", systemImage: "globe") { NSWorkspace.shared.open(website) }
                        .accessibilityIdentifier("about.website")
                }
                .controlSize(.small)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task { await updates.check() }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewPage(updates: updates)
            }
        }

        @ViewBuilder private var updateRow: some View {
            HStack {
                if updates.updateAvailable, let latest = updates.latest {
                    Label("Version \(latest.version) is available", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Spacer()
                    Link(destination: latest.html_url) { Label("Download", systemImage: "arrow.down.circle") }
                        .accessibilityIdentifier("about.download")
                } else {
                    Group {
                        switch updates.state {
                        case .checking: Label("Checking for updates…", systemImage: "arrow.triangle.2.circlepath")
                        case .upToDate: Label("You're up to date", systemImage: "checkmark.circle")
                        case .failed: Label("Couldn't check for updates", systemImage: "exclamationmark.triangle")
                        case .idle: EmptyView()
                        }
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Now", systemImage: "arrow.clockwise") { Task { await updates.check() } }
                        .disabled(updates.state == .checking)
                        .accessibilityIdentifier("about.checkNow")
                }
            }
            .font(.caption)
            .controlSize(.small)
        }

        private var bugTemplate: String {
            let os = ProcessInfo.processInfo.operatingSystemVersionString
            return "What happened:\n\n\nWhat you expected:\n\n\nSteps to reproduce:\n\n\n---\nApp version: \(appVersion)\nmacOS: \(os)\n"
        }

        private func mail(_ subject: String, body: String = "") {
            var c = URLComponents()
            c.scheme = "mailto"
            c.path = supportEmail
            c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
            if let url = c.url { NSWorkspace.shared.open(url) }
        }
    }
}
