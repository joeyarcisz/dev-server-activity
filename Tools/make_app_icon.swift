import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsDirectory = root.appendingPathComponent("Assets", isDirectory: true)
let iconsetDirectory = assetsDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let iconOutput = assetsDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillCircle(center: CGPoint, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )).fill()
}

func strokeLine(from start: CGPoint, to end: CGPoint, width: CGFloat, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.move(to: start)
    path.line(to: end)
    path.stroke()
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: CGSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let scale = size / 1024
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(canvas)

    let outer = canvas.insetBy(dx: 44 * scale, dy: 44 * scale)
    let outerPath = roundedRect(outer, radius: 218 * scale)

    NSGraphicsContext.saveGraphicsState()
    outerPath.addClip()

    NSGradient(colors: [
        NSColor(hex: 0x121820),
        NSColor(hex: 0x1c2730),
        NSColor(hex: 0x263640)
    ])?.draw(in: outer, angle: -42)

    NSColor(hex: 0x42e8d0, alpha: 0.18).setFill()
    NSBezierPath(ovalIn: CGRect(x: 600 * scale, y: 642 * scale, width: 310 * scale, height: 310 * scale)).fill()

    NSColor(hex: 0xffb34d, alpha: 0.14).setFill()
    NSBezierPath(ovalIn: CGRect(x: 86 * scale, y: 92 * scale, width: 360 * scale, height: 360 * scale)).fill()

    let panel = CGRect(x: 236 * scale, y: 258 * scale, width: 552 * scale, height: 404 * scale)
    NSColor(hex: 0x071015, alpha: 0.78).setFill()
    roundedRect(panel, radius: 74 * scale).fill()

    NSColor(hex: 0xbdd5dd, alpha: 0.22).setStroke()
    let panelStroke = roundedRect(panel.insetBy(dx: 7 * scale, dy: 7 * scale), radius: 66 * scale)
    panelStroke.lineWidth = 8 * scale
    panelStroke.stroke()

    let rackOne = CGRect(x: 298 * scale, y: 404 * scale, width: 428 * scale, height: 76 * scale)
    let rackTwo = CGRect(x: 298 * scale, y: 312 * scale, width: 428 * scale, height: 76 * scale)
    for rack in [rackOne, rackTwo] {
        NSColor(hex: 0x1d3038, alpha: 0.96).setFill()
        roundedRect(rack, radius: 26 * scale).fill()

        NSColor(hex: 0x8fb4bd, alpha: 0.18).setStroke()
        let stroke = roundedRect(rack.insetBy(dx: 3 * scale, dy: 3 * scale), radius: 23 * scale)
        stroke.lineWidth = 4 * scale
        stroke.stroke()

        NSColor(hex: 0xb7c8cd, alpha: 0.55).setFill()
        roundedRect(CGRect(x: rack.minX + 104 * scale, y: rack.midY - 9 * scale, width: 198 * scale, height: 18 * scale), radius: 9 * scale).fill()
        NSColor(hex: 0xb7c8cd, alpha: 0.28).setFill()
        roundedRect(CGRect(x: rack.minX + 104 * scale, y: rack.midY - 26 * scale, width: 112 * scale, height: 10 * scale), radius: 5 * scale).fill()
    }

    fillCircle(center: CGPoint(x: 342 * scale, y: 442 * scale), radius: 16 * scale, color: NSColor(hex: 0x42e8d0))
    fillCircle(center: CGPoint(x: 342 * scale, y: 350 * scale), radius: 16 * scale, color: NSColor(hex: 0xffb34d))

    let hub = CGPoint(x: 512 * scale, y: 720 * scale)
    let leftNode = CGPoint(x: 302 * scale, y: 744 * scale)
    let rightNode = CGPoint(x: 722 * scale, y: 744 * scale)
    let lowerNode = CGPoint(x: 512 * scale, y: 602 * scale)

    strokeLine(from: leftNode, to: hub, width: 18 * scale, color: NSColor(hex: 0x6d838b, alpha: 0.46))
    strokeLine(from: rightNode, to: hub, width: 18 * scale, color: NSColor(hex: 0x6d838b, alpha: 0.46))
    strokeLine(from: hub, to: lowerNode, width: 18 * scale, color: NSColor(hex: 0x6d838b, alpha: 0.46))

    fillCircle(center: hub, radius: 35 * scale, color: NSColor(hex: 0x42e8d0))
    fillCircle(center: leftNode, radius: 28 * scale, color: NSColor(hex: 0x42e8d0))
    fillCircle(center: rightNode, radius: 28 * scale, color: NSColor(hex: 0xffb34d))
    fillCircle(center: lowerNode, radius: 26 * scale, color: NSColor(hex: 0xd8edf0))

    NSColor(hex: 0x0d2024, alpha: 0.46).setFill()
    fillCircle(center: hub, radius: 13 * scale, color: NSColor(hex: 0x0d2024, alpha: 0.72))

    let stopOuter = CGRect(x: 662 * scale, y: 246 * scale, width: 138 * scale, height: 138 * scale)
    NSColor(hex: 0xf05b57).setFill()
    roundedRect(stopOuter, radius: 40 * scale).fill()

    NSColor(hex: 0xffd6cc, alpha: 0.92).setFill()
    roundedRect(CGRect(x: 704 * scale, y: 288 * scale, width: 54 * scale, height: 54 * scale), radius: 13 * scale).fill()

    NSGraphicsContext.restoreGraphicsState()

    NSColor(hex: 0xffffff, alpha: 0.16).setStroke()
    let outerStroke = roundedRect(outer.insetBy(dx: 5 * scale, dy: 5 * scale), radius: 212 * scale)
    outerStroke.lineWidth = 10 * scale
    outerStroke.stroke()

    image.unlockFocus()
    return image
}

func writePNG(size: Int, name: String) throws {
    let image = drawIcon(size: CGFloat(size))
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"])
    }

    try png.write(to: iconsetDirectory.appendingPathComponent(name))
}

let requiredFiles: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for file in requiredFiles {
    try writePNG(size: file.0, name: file.1)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", iconOutput.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "IconWriter", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print(iconOutput.path)
