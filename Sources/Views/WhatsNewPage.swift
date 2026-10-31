import SwiftUI

/// The What's New sheet: release notes for this version, and for the update when there is one.
struct WhatsNewPage: View {
    let updates: UpdateChecker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Text("What's New").font(.title2.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    if updates.updateAvailable, let latest = updates.latest {
                        ReleaseNotesSection(release: latest, title: "Available: v\(latest.version)")
                    }
                    if let current = updates.current {
                        ReleaseNotesSection(release: current, title: "This version: v\(current.version)")
                    } else if updates.state == .checking {
                        ProgressView()
                    } else {
                        Text("Release notes for v\(appVersion) aren't available right now.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if updates.updateAvailable, let latest = updates.latest {
                    Link(destination: latest.html_url) { Label("Download v\(latest.version)", systemImage: "arrow.down.circle") }
                        .accessibilityIdentifier("whatsNew.download")
                }
                Spacer()
                Button("Close", systemImage: "xmark") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("whatsNew.close")
            }
        }
        .padding(Spacing.page)
        .frame(width: Metrics.WhatsNew.size.width, height: Metrics.WhatsNew.size.height)
    }
}

/// One release's notes, rendered from GitHub's markdown.
private struct ReleaseNotesSection: View {
    let release: Release
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.headline)
            // ponytail: line-by-line markdown: headings bold, quotes and GitHub callouts unwrapped, the rest inline only.
            ForEach(Array((release.body ?? "").components(separatedBy: .newlines).enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
                if line.hasPrefix("#") {
                    Text(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
                        .font(.subheadline.bold())
                        .padding(.top, Spacing.xs)
                } else if !line.isEmpty, !line.hasPrefix("[!"), !line.hasPrefix("```") {
                    Text((try? AttributedString(markdown: line)) ?? AttributedString(line)).font(.callout)
                }
            }
        }
        .textSelection(.enabled)
    }
}
