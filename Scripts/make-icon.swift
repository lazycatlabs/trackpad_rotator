// Renders the app icon at 1024×1024 with CoreGraphics.
// Usage: swift Scripts/make-icon.swift <output.png>
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let space = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, a,
    ])!
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// Flip so +y is down, like the design coordinates.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// MARK: Background squircle (macOS icon grid: 824pt body, 100pt margin)

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 36, color: rgb(0x000000, 0.35))
ctx.addPath(squircle)
ctx.setFillColor(rgb(0x111827))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0x1E1B4B), rgb(0x0B1020)]),
                       start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
// Soft glow behind the pad.
ctx.drawRadialGradient(gradient([rgb(0x6366F1, 0.55), rgb(0x6366F1, 0)]),
                       startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 470), endRadius: 430, options: [])
// Top sheen.
ctx.drawLinearGradient(gradient([rgb(0xFFFFFF, 0.10), rgb(0xFFFFFF, 0)]),
                       start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 420), options: [])
ctx.restoreGState()

// Hairline edge.
ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.setStrokeColor(rgb(0xFFFFFF, 0.12))
ctx.setLineWidth(3)
ctx.strokePath()

// MARK: Rotation arrows (two arcs around the pad)

let center = CGPoint(x: 512, y: 512)
let arcRadius: CGFloat = 330
let arcWidth: CGFloat = 40
let arcGradient = gradient([rgb(0x22D3EE), rgb(0xA78BFA)])

func arrowArc(from a0: CGFloat, to a1: CGFloat) {
    let path = CGMutablePath()
    path.addArc(center: center, radius: arcRadius, startAngle: a0, endAngle: a1, clockwise: false)
    let stroked = path.copy(strokingWithWidth: arcWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)

    // Arrowhead at the end, pointing along the direction of travel.
    let end = CGPoint(x: center.x + arcRadius * cos(a1), y: center.y + arcRadius * sin(a1))
    let tangent = a1 + .pi / 2
    let head = CGMutablePath()
    let len: CGFloat = 92, half: CGFloat = 62
    let tip = CGPoint(x: end.x + len * 0.62 * cos(tangent), y: end.y + len * 0.62 * sin(tangent))
    let back = CGPoint(x: end.x - len * 0.38 * cos(tangent), y: end.y - len * 0.38 * sin(tangent))
    head.move(to: tip)
    head.addLine(to: CGPoint(x: back.x + half * cos(a1), y: back.y + half * sin(a1)))
    head.addLine(to: CGPoint(x: back.x - half * cos(a1), y: back.y - half * sin(a1)))
    head.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 28, color: rgb(0x22D3EE, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(stroked)
    ctx.addPath(head)
    ctx.clip()
    ctx.drawLinearGradient(arcGradient,
                           start: CGPoint(x: center.x + arcRadius * cos(a0), y: center.y + arcRadius * sin(a0)),
                           end: tip, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

// Angles are in the flipped space; increasing angle runs clockwise on screen.
arrowArc(from: .pi * 1.08, to: .pi * 1.62)
arrowArc(from: .pi * 0.08, to: .pi * 0.62)

// MARK: Trackpad, turned to portrait

let pad = CGRect(x: 512 - 178, y: 512 - 244, width: 356, height: 488)
let padPath = CGPath(roundedRect: pad, cornerWidth: 46, cornerHeight: 46, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 26), blur: 50, color: rgb(0x000000, 0.55))
ctx.addPath(padPath)
ctx.setFillColor(rgb(0xE5E7EB))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(padPath)
ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0xFAFAFB), rgb(0xD9DCE3), rgb(0xC3C8D2)], [0, 0.55, 1]),
                       start: CGPoint(x: pad.minX, y: pad.minY), end: CGPoint(x: pad.maxX, y: pad.maxY), options: [])
// Glass sheen.
ctx.drawLinearGradient(gradient([rgb(0xFFFFFF, 0.65), rgb(0xFFFFFF, 0)]),
                       start: CGPoint(x: pad.minX, y: pad.minY), end: CGPoint(x: pad.midX, y: pad.midY - 40), options: [])
ctx.restoreGState()

ctx.addPath(CGPath(roundedRect: pad.insetBy(dx: 2, dy: 2), cornerWidth: 44, cornerHeight: 44, transform: nil))
ctx.setStrokeColor(rgb(0xFFFFFF, 0.9))
ctx.setLineWidth(4)
ctx.strokePath()

// MARK: Touch points with a swipe trail

func touch(_ p: CGPoint, trailTo q: CGPoint) {
    let trail = CGMutablePath()
    trail.move(to: q)
    trail.addLine(to: p)
    let stroked = trail.copy(strokingWithWidth: 26, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addPath(stroked)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0x6366F1, 0), rgb(0x6366F1, 0.55)]), start: q, end: p, options: [])
    ctx.restoreGState()

    ctx.drawRadialGradient(gradient([rgb(0x22D3EE, 0.55), rgb(0x22D3EE, 0)]),
                           startCenter: p, startRadius: 0, endCenter: p, endRadius: 82, options: [])
    ctx.addEllipse(in: CGRect(x: p.x - 34, y: p.y - 34, width: 68, height: 68))
    ctx.setFillColor(rgb(0x4F46E5))
    ctx.fillPath()
    ctx.addEllipse(in: CGRect(x: p.x - 34, y: p.y - 34, width: 68, height: 68))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.95))
    ctx.setLineWidth(7)
    ctx.strokePath()
}

// A single swipe heading up-right, toward where the arrows turn.
touch(CGPoint(x: 566, y: 418), trailTo: CGPoint(x: 444, y: 620))

// MARK: Write PNG

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Failed to write \(out)") }
print("Wrote \(out)")
