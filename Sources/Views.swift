import SwiftUI

// MARK: - Shared controls

struct StatusBanner: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if !model.accessibilityGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Accessibility permission needed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout.weight(.semibold))
                Text("Turn on Trackpad Rotator in System Settings → Privacy & Security → Accessibility so it can remap the pointer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
                    .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else if !model.inputMonitoringGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Input Monitoring permission needed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout.weight(.semibold))
                Text("Turn on Trackpad Rotator in System Settings → Privacy & Security → Input Monitoring so it can tell when your fingers are on the Magic Trackpad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Input Monitoring Settings") { model.openInputMonitoringSettings() }
                    .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        } else if !model.multitouchAvailable {
            Label("Multitouch framework unavailable: can't tell trackpad from mouse.", systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

struct PermissionsList: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PermissionRow(title: "Accessibility",
                          detail: "Moves the pointer and rewrites scroll events.",
                          granted: model.accessibilityGranted,
                          request: model.requestAccessibility,
                          openSettings: model.openAccessibilitySettings)
            PermissionRow(title: "Input Monitoring",
                          detail: "Reads finger data from the trackpad.",
                          granted: model.inputMonitoringGranted,
                          request: model.requestInputMonitoring,
                          openSettings: model.openInputMonitoringSettings)
            HStack {
                Text(model.accessibilityGranted && model.inputMonitoringGranted
                     ? "All permissions granted."
                     : "Checked automatically every 2 seconds.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check Again") { model.refresh() }
                    .controlSize(.small)
            }
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var detail: String
    var granted: Bool
    var request: () -> Void
    var openSettings: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
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

struct OrientationControls: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Orientation", selection: $store.config.transform.rotation) {
                ForEach(Rotation.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)

            Text(store.config.transform.rotation.longLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Touch point axes").font(.subheadline.weight(.semibold))
            HStack(spacing: 16) {
                Toggle("Swap X ↔ Y", isOn: $store.config.transform.swapXY)
                Toggle("Invert X", isOn: $store.config.transform.invertX)
                Toggle("Invert Y", isOn: $store.config.transform.invertY)
            }
            .toggleStyle(.checkbox)
        }
    }
}

struct ApplyControls: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Remap pointer movement", isOn: $store.config.applyToPointer)
            Toggle("Remap two‑finger scrolling", isOn: $store.config.applyToScroll)
            Toggle("Swipe between pages (back/forward)", isOn: $store.config.swipeNavigation)
                .disabled(!store.config.applyToScroll)
            Toggle("Right‑edge swipe opens Notification Center", isOn: $store.config.notificationCenterSwipe)
            Toggle("Three‑ and four‑finger swipes", isOn: $store.config.dockSwipes)
        }
        .toggleStyle(.checkbox)
    }
}

struct SpeedControls: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpeedSlider(title: "Pointer speed", value: $store.config.pointerSpeed)
                .disabled(!store.config.applyToPointer)
            SpeedSlider(title: "Scroll speed", value: $store.config.scrollSpeed)
                .disabled(!store.config.applyToScroll)
            Text("Applied on top of the Tracking speed in System Settings → Trackpad.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SpeedSlider: View {
    var title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2g×", value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    value = 1
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to 1×")
                .opacity(value == 1 ? 0 : 1)
            }
            Slider(value: $value, in: 0.25...3, step: 0.05) {
                EmptyView()
            } minimumValueLabel: {
                Image(systemName: "tortoise").font(.caption)
            } maximumValueLabel: {
                Image(systemName: "hare").font(.caption)
            }
            .labelsHidden()
        }
    }
}

// MARK: - Menu bar panel

struct MenuPanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: SettingsStore
    @Environment(\.openWindow) private var openWindow
    @State private var showPermissions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trackpad Rotator").font(.headline)
                Spacer()
                Toggle("", isOn: $store.config.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            StatusBanner()
            OrientationControls()
            Divider()
            ApplyControls()
            SpeedControls()
            Divider()
            DisclosureGroup(isExpanded: $showPermissions) {
                PermissionsList().padding(.top, 6)
            } label: {
                Label("Permissions", systemImage: model.accessibilityGranted && model.inputMonitoringGranted
                      ? "checkmark.shield" : "exclamationmark.shield")
            }
            Divider()
            HStack {
                Button("Touch Preview & Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}

// MARK: - Main window

struct MainWindow: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                TouchPreview(transform: store.config.transform, target: store.config.target)
                Text("Put your fingers on the trackpad. The left pad shows the raw touch points the trackpad reports; the right pad shows them after your orientation and X/Y settings. When it's right, moving your finger \u{201C}up\u{201D} makes the dot on the right move up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 520, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Toggle("Enabled", isOn: $store.config.enabled)
                        .toggleStyle(.switch)
                        .font(.headline)
                    Spacer()
                    Button("Reset X/Y") { store.resetAxes() }
                        .controlSize(.small)
                }
                StatusBanner()
                GroupBox("Orientation") {
                    OrientationControls().padding(6)
                }
                GroupBox("Apply to") {
                    VStack(alignment: .leading, spacing: 8) {
                        ApplyControls()
                        Picker("Devices", selection: $store.config.target) {
                            ForEach(DeviceTarget.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                            let active = TouchMonitor.shared.isTargetActive(store.config.target)
                            Label(active ? "Trackpad in use: remapping" : "Trackpad idle",
                                  systemImage: active ? "hand.point.up.left.fill" : "hand.raised.slash")
                                .font(.caption)
                                .foregroundStyle(active ? .green : .secondary)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Speed") {
                    SpeedControls().padding(6)
                }
                GroupBox("Permissions") {
                    PermissionsList().padding(6)
                }
                GroupBox("Detected devices") {
                    VStack(alignment: .leading, spacing: 4) {
                        if model.devices.isEmpty {
                            Text("None found").foregroundStyle(.secondary)
                        }
                        ForEach(model.devices) { d in
                            HStack {
                                Image(systemName: d.matches(store.config.target) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(d.matches(store.config.target) ? .green : .secondary)
                                Text(d.name)
                                Spacer()
                                if d.info.width > 0 {
                                    Text(String(format: "%.0f×%.0f mm", d.widthMM, d.heightMM))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.callout)
                        }
                        Button("Rescan") { model.rescanDevices() }
                            .controlSize(.small)
                            .padding(.top, 4)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle("Launch at login", isOn: $store.launchAtLogin)
                    .toggleStyle(.checkbox)
                Text("System gestures (Mission Control swipes, pinch, rotate) are handled by macOS and are not remapped.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 320)
        }
        .padding(20)
    }
}

private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
}

// MARK: - Live touch preview

struct TouchPreview: View {
    var transform: AxisTransform
    var target: DeviceTarget

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { _ in
            let device = pickDevice()
            HStack(spacing: 16) {
                PadCanvas(title: "Raw (trackpad's view)", device: device, transform: AxisTransform())
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                PadCanvas(title: "Mapped (your view)", device: device, transform: transform)
            }
        }
    }

    /// Prefer the device being touched right now, then any targeted trackpad.
    private func pickDevice() -> DeviceSnapshot? {
        let all = TouchMonitor.shared.snapshot()
        return all.filter { $0.isTrackpad }.max { $0.lastTouch < $1.lastTouch }
            ?? all.first { $0.matches(target) }
            ?? all.first
    }
}

struct PadCanvas: View {
    var title: String
    var device: DeviceSnapshot?
    var transform: AxisTransform

    private static let palette: [Color] = [.blue, .pink, .green, .orange, .purple, .teal, .yellow, .red, .indigo, .mint]

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Canvas { ctx, size in
                draw(in: &ctx, size: size)
            }
            .frame(width: 240, height: 240)
            Text(readout).font(.caption.monospaced()).foregroundStyle(.secondary)
                .frame(height: 30, alignment: .top)
        }
    }

    private var padSize: (w: Double, h: Double) {
        if let d = device, d.info.width > 0, d.info.height > 0 { return (d.widthMM, d.heightMM) }
        return (160, 115) // Magic Trackpad
    }

    /// Converts a normalized touch to a point relative to the pad centre in the mapped frame (mm).
    private func mapped(_ t: TouchPoint) -> (x: Double, y: Double) {
        let (w, h) = padSize
        let px = (Double(t.x) - 0.5) * w
        let py = (0.5 - Double(t.y)) * h // flip so +y is down
        return transform.apply(px, py)
    }

    private var readout: String {
        guard let t = device?.touches.first(where: \.isTouching) else { return "no touch" }
        let (w, h) = padSize
        let m = mapped(t)
        let out = transform.apply(w, h)
        let nx = m.x / abs(out.x) + 0.5
        let ny = 0.5 - m.y / abs(out.y)
        return String(format: "x %.2f  y %.2f", nx, ny)
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize) {
        let (w, h) = padSize
        let outDims = transform.apply(w, h)
        let ow = abs(outDims.x), oh = abs(outDims.y)
        let scale = min((size.width - 20) / ow, (size.height - 20) / oh)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rect = CGRect(x: center.x - ow * scale / 2, y: center.y - oh * scale / 2, width: ow * scale, height: oh * scale)

        ctx.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(.secondary.opacity(0.12)))
        ctx.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(.secondary.opacity(0.5)), lineWidth: 1)

        func toView(_ p: (x: Double, y: Double)) -> CGPoint {
            CGPoint(x: center.x + p.x * scale, y: center.y + p.y * scale)
        }

        // Mark the trackpad's own top edge (the edge farthest from you when it's unrotated).
        let topMid = toView(transform.apply(0, -h / 2))
        let topA = toView(transform.apply(-w * 0.2, -h / 2))
        let topB = toView(transform.apply(w * 0.2, -h / 2))
        var edge = Path()
        edge.move(to: topA)
        edge.addLine(to: topB)
        ctx.stroke(edge, with: .color(.accentColor), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        let labelPos = CGPoint(x: center.x + (topMid.x - center.x) * 0.78, y: center.y + (topMid.y - center.y) * 0.78)
        ctx.draw(Text("pad top").font(.caption2).foregroundColor(.accentColor), at: labelPos)

        // Arrow showing the trackpad's own +X direction.
        let xFrom = toView(transform.apply(-w * 0.15, h * 0.32))
        let xTo = toView(transform.apply(w * 0.15, h * 0.32))
        var arrow = Path()
        arrow.move(to: xFrom)
        arrow.addLine(to: xTo)
        ctx.stroke(arrow, with: .color(.secondary.opacity(0.6)), lineWidth: 1.5)
        ctx.fill(Path(ellipseIn: CGRect(x: xTo.x - 3, y: xTo.y - 3, width: 6, height: 6)), with: .color(.secondary.opacity(0.6)))
        ctx.draw(Text("pad +X").font(.caption2).foregroundColor(.secondary),
                 at: CGPoint(x: (xFrom.x + xTo.x) / 2, y: (xFrom.y + xTo.y) / 2 - 9))

        guard let touches = device?.touches else { return }
        for t in touches where (1...6).contains(t.state) {
            let p = toView(mapped(t))
            let r = max(9, min(22, Double(t.size) * 14))
            let color = Self.palette[Int(abs(t.id)) % Self.palette.count]
            let circle = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(circle, with: .color(color.opacity(t.isTouching ? 0.85 : 0.25)))
            ctx.draw(Text("\(t.id)").font(.caption2.bold()).foregroundColor(.white), at: p)
        }
    }
}
