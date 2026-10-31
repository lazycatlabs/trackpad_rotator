import SwiftUI

extension MainPage {
    /// The live touch preview: the raw pad next to the pad after the user's orientation.
    struct TouchPreviewSection: View {
        @Environment(StatusViewModel.self) private var status
        var transform: AxisTransform
        var target: DeviceTarget

        var body: some View {
            TimelineView(.animation(minimumInterval: 1 / Metrics.Pad.frameRate)) { _ in
                let device = pickDevice()
                HStack(spacing: Spacing.xxl) {
                    PadCanvas(title: "Raw (trackpad's view)", device: device, transform: AxisTransform())
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    PadCanvas(title: "Mapped (your view)", device: device, transform: transform)
                }
            }
        }

        /// Prefer the device being touched right now, then any targeted trackpad.
        private func pickDevice() -> DeviceSnapshot? {
            let all = status.liveDevices()
            return all.filter { $0.isTrackpad }.max { $0.lastTouch < $1.lastTouch }
                ?? all.first { $0.matches(target) }
                ?? all.first
        }
    }
}

private struct PadCanvas: View {
    typealias Pad = Metrics.Pad

    var title: LocalizedStringKey
    var device: DeviceSnapshot?
    var transform: AxisTransform

    private static let palette: [Color] = [.blue, .pink, .green, .orange, .purple, .teal, .yellow, .red, .indigo, .mint]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Canvas { ctx, size in
                draw(in: &ctx, size: size)
            }
            .frame(width: Pad.canvas, height: Pad.canvas)
            Text(readout).font(.caption.monospaced()).foregroundStyle(.secondary)
                .frame(height: Pad.readoutHeight, alignment: .top)
        }
    }

    private var padSize: (w: Double, h: Double) {
        if let d = device, d.info.width > 0, d.info.height > 0 { return (d.widthMM, d.heightMM) }
        return Pad.defaultSizeMM
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
        let scale = min((size.width - Pad.inset * 2) / ow, (size.height - Pad.inset * 2) / oh)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rect = CGRect(x: center.x - ow * scale / 2, y: center.y - oh * scale / 2, width: ow * scale, height: oh * scale)
        let face = Path(roundedRect: rect, cornerRadius: Radius.lg)

        ctx.fill(face, with: .color(.secondary.opacity(Opacity.fill)))
        ctx.stroke(face, with: .color(.secondary.opacity(Opacity.border)), lineWidth: Metrics.hairline)

        func toView(_ p: (x: Double, y: Double)) -> CGPoint {
            CGPoint(x: center.x + p.x * scale, y: center.y + p.y * scale)
        }

        // Mark the trackpad's own top edge (the edge farthest from you when it's unrotated).
        let topMid = toView(transform.apply(0, -h / 2))
        var edge = Path()
        edge.move(to: toView(transform.apply(-w * Pad.topEdgeHalfLength, -h / 2)))
        edge.addLine(to: toView(transform.apply(w * Pad.topEdgeHalfLength, -h / 2)))
        ctx.stroke(edge, with: .color(.accentColor), style: StrokeStyle(lineWidth: Pad.topEdgeWidth, lineCap: .round))
        let labelPos = CGPoint(x: center.x + (topMid.x - center.x) * Pad.topLabelPosition,
                               y: center.y + (topMid.y - center.y) * Pad.topLabelPosition)
        ctx.draw(Text("pad top").font(.caption2).foregroundColor(.accentColor), at: labelPos)

        // Arrow showing the trackpad's own +X direction.
        let xFrom = toView(transform.apply(-w * Pad.axisHalfLength, h * Pad.axisOffset))
        let xTo = toView(transform.apply(w * Pad.axisHalfLength, h * Pad.axisOffset))
        var arrow = Path()
        arrow.move(to: xFrom)
        arrow.addLine(to: xTo)
        let axisColor = GraphicsContext.Shading.color(.secondary.opacity(Opacity.muted))
        ctx.stroke(arrow, with: axisColor, lineWidth: Pad.axisWidth)
        let head = Pad.axisHeadRadius
        ctx.fill(Path(ellipseIn: CGRect(x: xTo.x - head, y: xTo.y - head, width: head * 2, height: head * 2)), with: axisColor)
        ctx.draw(Text("pad +X").font(.caption2).foregroundColor(.secondary),
                 at: CGPoint(x: (xFrom.x + xTo.x) / 2, y: (xFrom.y + xTo.y) / 2 - Pad.axisLabelLift))

        guard let touches = device?.touches else { return }
        for t in touches where (1...6).contains(t.state) {
            let p = toView(mapped(t))
            let r = min(Pad.touchRadius.upperBound, max(Pad.touchRadius.lowerBound, Double(t.size) * Pad.touchScale))
            let color = Self.palette[Int(abs(t.id)) % Self.palette.count]
            let circle = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(circle, with: .color(color.opacity(t.isTouching ? Opacity.strong : Opacity.faint)))
            ctx.draw(Text("\(t.id)").font(.caption2.bold()).foregroundColor(.white), at: p)
        }
    }
}

