import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

func drawIcon() {
    func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
    }
    func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    let tile = rounded(88, 88, 848, 848, 190)
    NSGradient(starting: color(0.12, 0.31, 0.36), ending: color(0.035, 0.10, 0.15))!
        .draw(in: tile, angle: -65)
    let screen = rounded(242, 305, 540, 411, 103)
    color(0.045, 0.14, 0.19).setFill()
    screen.fill()
    color(0.51, 0.82, 0.78).setStroke()
    screen.lineWidth = 24
    screen.stroke()

    color(0.75, 0.87, 0.86).setFill()
    rounded(319, 563, 213, 30, 15).fill()
    rounded(319, 425, 247, 30, 15).fill()
    color(0.45, 0.94, 0.79).setFill()
    rounded(319, 491, 315, 36, 18).fill()
    NSBezierPath(ovalIn: NSRect(x: 660, y: 489, width: 40, height: 40)).fill()
}

for dimension in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = dimension * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let factor = CGFloat(pixels) / 1024
        context.cgContext.scaleBy(x: factor, y: factor)
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()

        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(dimension)x\(dimension)\(suffix).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
