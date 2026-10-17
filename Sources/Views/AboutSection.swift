import SwiftUI

// MARK: - About

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

private let supportEmail = "admin@lazycatlabs.com"
private let website = URL(string: "https://trackpadrotator.lazycatlabs.com/")!
private let releasesAPI = "https://api.github.com/repos/lazycatlabs/trackpad_rotator/releases"

struct Release: Decodable {
    let tag_name: String
    let body: String?
    let html_url: URL

    var version: String { String(tag_name.dropFirst()) }
    /// Only `vX.Y.Z` tags count; `v2.0.0-beta` and the like are never offered.
    var isStable: Bool { tag_name.wholeMatch(of: /v\d+\.\d+\.\d+/) != nil }
    func isNewer(than other: String) -> Bool {
        version.compare(other, options: .numeric) == .orderedDescending
    }
}

/// Reads GitHub Releases: the latest one is the update, the one tagged with this build is "What's New".
@MainActor @Observable
final class UpdateChecker {
    enum State: Equatable { case idle, checking, upToDate, failed }

    private(set) var state = State.idle
    private(set) var latest: Release?
    private(set) var current: Release?

    var updateAvailable: Bool { latest?.isNewer(than: appVersion) ?? false }

    func check() async {
        state = .checking
        do {
            // releases/latest already skips drafts and pre-releases, so no paging is needed.
            async let latest = fetch("latest")
            async let current = fetch("tags/v\(appVersion)")
            self.latest = try await latest.flatMap { $0.isStable ? $0 : nil }
            self.current = try await current
            state = .upToDate
        } catch {
            state = .failed
        }
    }

    /// The release at `releases/<path>`, or nil when GitHub has none (404).
    private func fetch(_ path: String) async throws -> Release? {
        var request = URLRequest(url: URL(string: "\(releasesAPI)/\(path)")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try JSONDecoder().decode(Release.self, from: data)
        case 404: return nil
        default: throw URLError(.badServerResponse)
        }
    }
}

struct AboutSection: View {
    @State private var updates = UpdateChecker()
    @State private var showWhatsNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trackpad Rotator v\(appVersion)").font(.callout)
                Spacer()
                Button("What's New", systemImage: "sparkles") { showWhatsNew = true }
                    .controlSize(.small)
            }
            updateRow
            Divider()
            HStack {
                Button("Feedback", systemImage: "bubble.left") { mail("Trackpad Rotator Feedback") }
                Button("Report Bug", systemImage: "ladybug") { mail("Trackpad Rotator Bug Report", body: bugTemplate) }
                Button("Website", systemImage: "globe") { NSWorkspace.shared.open(website) }
            }
            .controlSize(.small)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await updates.check() }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet(updates: updates)
        }
    }

    @ViewBuilder private var updateRow: some View {
        HStack {
            if updates.updateAvailable, let latest = updates.latest {
                Label("Version \(latest.version) is available", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                Spacer()
                Link(destination: latest.html_url) { Label("Download", systemImage: "arrow.down.circle") }
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

// MARK: - What's New

private struct WhatsNewSheet: View {
    let updates: UpdateChecker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's New").font(.title2.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if updates.updateAvailable, let latest = updates.latest {
                        notes(latest, title: "Available: v\(latest.version)")
                    }
                    if let current = updates.current {
                        notes(current, title: "This version: v\(current.version)")
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
                }
                Spacer()
                Button("Close", systemImage: "xmark") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 420)
    }

    private func notes(_ release: Release, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            // ponytail: line-by-line markdown: headings bold, quotes and GitHub callouts unwrapped, the rest inline only.
            ForEach(Array((release.body ?? "").components(separatedBy: .newlines).enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
                if line.hasPrefix("#") {
                    Text(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)).font(.subheadline.bold()).padding(.top, 4)
                } else if !line.isEmpty, !line.hasPrefix("[!"), !line.hasPrefix("```") {
                    Text((try? AttributedString(markdown: line)) ?? AttributedString(line)).font(.callout)
                }
            }
        }
        .textSelection(.enabled)
    }
}
