import Foundation
import Observation

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

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
