import SwiftUI

/// Which kinds of input get remapped.
struct ApplySection: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle("Remap pointer movement", isOn: $settings.config.applyToPointer)
                .accessibilityIdentifier("apply.pointer")
            Toggle("Remap two‑finger scrolling", isOn: $settings.config.applyToScroll)
                .accessibilityIdentifier("apply.scroll")
            Toggle("Swipe between pages (back/forward)", isOn: $settings.config.swipeNavigation)
                .disabled(!settings.config.applyToScroll)
                .accessibilityIdentifier("apply.swipeNavigation")
            Toggle("Right‑edge swipe opens Notification Center", isOn: $settings.config.notificationCenterSwipe)
                .accessibilityIdentifier("apply.notificationCenter")
            Toggle("Three‑ and four‑finger swipes", isOn: $settings.config.dockSwipes)
                .accessibilityIdentifier("apply.dockSwipes")
        }
        .toggleStyle(.checkbox)
    }
}
