import SwiftUI

extension MainPage {
    /// Ways to back the project: sponsorship and tip links, the same ones as the repo's FUNDING.yml.
    struct SupportSection: View {
        private static let options: [Option] = [
            Option(id: "githubSponsors", title: "GitHub Sponsors", detail: "Monthly or one-time, through GitHub.",
                   icon: "heart.fill", url: "https://github.com/sponsors/Lzyct"),
            Option(id: "buyMeACoffee", title: "Buy Me a Coffee", detail: "A one-time tip.",
                   icon: "cup.and.saucer.fill", url: "https://buymeacoffee.com/Lzyct"),
            Option(id: "koFi", title: "Ko-fi", detail: "A one-time tip.",
                   icon: "mug.fill", url: "https://ko-fi.com/Lzyct"),
            Option(id: "paypal", title: "PayPal", detail: "Send any amount.",
                   icon: "creditcard.fill", url: "https://paypal.me/ukieTux"),
            Option(id: "saweria", title: "Saweria", detail: "For supporters in Indonesia.",
                   icon: "gift.fill", url: "https://saweria.co/Lzyct"),
        ]
        private static let repo = URL(string: "https://github.com/lazycatlabs/trackpad_rotator")!

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Trackpad Rotator is free. If it helps you, you can help keep it going.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                GroupBox("Support") {
                    VStack(spacing: Spacing.md) {
                        ForEach(Self.options) { option in
                            if option.id != Self.options.first?.id { Divider() }
                            Item(option: option)
                        }
                    }
                    .padding(Spacing.sm)
                }
                GroupBox("Spread the word") {
                    HStack {
                        Label("Star the project on GitHub", systemImage: "star")
                        Spacer()
                        Link("Open GitHub", destination: Self.repo)
                            .accessibilityIdentifier("support.github")
                    }
                    .padding(Spacing.sm)
                }
            }
        }

        struct Option: Identifiable {
            var id: String
            var title: LocalizedStringKey
            var detail: LocalizedStringKey
            var icon: String
            var url: String
        }

        /// One sponsorship or tip link.
        struct Item: View {
            var option: Option

            var body: some View {
                HStack(spacing: Spacing.lg) {
                    Image(systemName: option.icon)
                        .foregroundStyle(.pink)
                        .frame(width: Metrics.Main.rowIconWidth)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(option.title)
                        Text(option.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open") { NSWorkspace.shared.open(URL(string: option.url)!) }
                        .accessibilityIdentifier("support.\(option.id)")
                }
            }
        }
    }
}
