import SwiftUI

/// The settings window: a sidebar of panes, each a scrolling page of grouped settings.
struct MainPage: View {
    @State private var pane: Pane = .general

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.icon)
                    .tag(pane)
                    .accessibilityIdentifier("sidebar.\(pane.rawValue)")
            }
            .navigationSplitViewColumnWidth(Metrics.Main.sidebarWidth)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(pane.title).font(.largeTitle.bold())
                        Text(pane.subtitle).foregroundStyle(.secondary)
                    }
                    content
                }
                .padding(Metrics.Main.detailPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: Metrics.Main.detailMinWidth, minHeight: Metrics.Main.minHeight)
        }
        .navigationTitle("") // the pane's own header is the title
    }

    @ViewBuilder private var content: some View {
        switch pane {
        case .general: GeneralSection()
        case .orientation: OrientationPane()
        case .gestures: GroupBox("Apply to") { TargetSection().padding(Spacing.sm) }
        case .speed: GroupBox("Speed") { SpeedSection().padding(Spacing.sm) }
        case .edges: GroupBox("Edge sliders") { EdgeSliderSection().padding(Spacing.sm) }
        case .permissions: GroupBox("Permissions") { PermissionsSection().padding(Spacing.sm) }
        case .devices: GroupBox("Detected devices") { DevicesSection().padding(Spacing.sm) }
        case .support: SupportSection()
        case .about: GroupBox("Trackpad Rotator") { AboutSection() }
        }
    }
}

extension MainPage {
    enum Pane: String, CaseIterable, Identifiable {
        case general, orientation, gestures, speed, edges, permissions, devices, support, about
        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .general: "General"
            case .orientation: "Orientation"
            case .gestures: "Gestures"
            case .speed: "Speed"
            case .edges: "Volume & Brightness"
            case .permissions: "Permissions"
            case .devices: "Devices"
            case .support: "Support"
            case .about: "About"
            }
        }

        var subtitle: LocalizedStringKey {
            switch self {
            case .general: "Turning remapping on, and starting Trackpad Rotator."
            case .orientation: "How your trackpad is turned, checked live with your fingers."
            case .gestures: "What gets remapped, and on which devices."
            case .speed: "Pointer and scroll speed for the remapped trackpad."
            case .edges: "Slide along the trackpad's edges to change volume and brightness."
            case .permissions: "What macOS needs to allow for remapping to work."
            case .devices: "Trackpads and mice Trackpad Rotator can see."
            case .support: "Trackpad Rotator is free. If it helps you, you can help keep it going."
            case .about: "Version, updates, and feedback."
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .orientation: "rotate.right"
            case .gestures: "hand.draw"
            case .speed: "gauge.with.dots.needle.67percent"
            case .edges: "slider.vertical.3"
            case .permissions: "lock.shield"
            case .devices: "rectangle.and.hand.point.up.left"
            case .support: "heart"
            case .about: "info.circle"
            }
        }
    }

    /// Master switch, the first blocking problem if any, and starting at login.
    struct GeneralSection: View {
        @Environment(SettingsViewModel.self) private var settings

        var body: some View {
            @Bindable var settings = settings
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                StatusBanner()
                GroupBox("Remapping") {
                    SwitchRow(title: "Enabled", icon: "power", isOn: $settings.config.enabled)
                        .accessibilityIdentifier("main.enabled")
                }
                GroupBox("Startup") {
                    SwitchRow(title: "Open at login", icon: "arrow.right.circle", isOn: $settings.launchAtLogin)
                        .accessibilityIdentifier("main.launchAtLogin")
                }
                Text("System gestures (Mission Control swipes, pinch, rotate) are handled by macOS and are not remapped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The live touch preview above the orientation controls.
    struct OrientationPane: View {
        @Environment(SettingsViewModel.self) private var settings

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                GroupBox("Touch preview") {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        TouchPreviewSection(transform: settings.config.transform, target: settings.config.target)
                            .frame(maxWidth: .infinity)
                        Text("Put your fingers on the trackpad. The left pad shows the raw touch points the trackpad reports; the right pad shows them after your orientation and X/Y settings. When it's right, moving your finger \u{201C}up\u{201D} makes the dot on the right move up.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.sm)
                }
                GroupBox("Orientation") {
                    VStack(alignment: .trailing, spacing: Spacing.md) {
                        OrientationSection()
                        // Inside the box: a button in a GroupBox label doesn't take clicks.
                        Button("Reset X/Y") { settings.resetAxes() }
                            .controlSize(.small)
                            .accessibilityIdentifier("main.resetAxes")
                    }
                    .padding(Spacing.sm)
                }
            }
        }
    }
}

/// A full-width settings row: icon and title on the left, a switch on the right.
private struct SwitchRow: View {
    var title: LocalizedStringKey
    var icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .padding(Spacing.sm)
    }
}
