import SwiftUI

// MARK: - Live touch preview

struct TouchPreview: View {
    @EnvironmentObject var status: StatusViewModel
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
        let all = status.liveDevices()
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
