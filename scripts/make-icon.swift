import AppKit
import Foundation

// Render a vector icon at each required resolution; no downloaded assets.
let output = CommandLine.arguments[1]
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let iconset = temporary.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer {
    do { try FileManager.default.removeItem(at: temporary) }
    catch { fputs("Could not remove temporary icon assets: \(error)\n", stderr) }
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let dimension = CGFloat(pixels)
        let rect = NSRect(x: dimension * 0.06, y: dimension * 0.06, width: dimension * 0.88, height: dimension * 0.88)
        NSColor(calibratedRed: 0.04, green: 0.43, blue: 0.44, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: dimension * 0.2, yRadius: dimension * 0.2).fill()
        let path = NSBezierPath()
        let low = dimension * 0.25, high = dimension * 0.75, arm = dimension * 0.13
        for (x, y, dx, dy) in [(low, low, arm, arm), (high, low, -arm, arm),
                                (low, high, arm, -arm), (high, high, -arm, -arm)] {
            path.move(to: NSPoint(x: x, y: y + dy))
            path.line(to: NSPoint(x: x, y: y))
            path.line(to: NSPoint(x: x + dx, y: y))
        }
        path.lineWidth = max(1, dimension * 0.045)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.white.setStroke()
        path.stroke()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        ("T" as NSString).draw(in: NSRect(x: 0, y: dimension * 0.29, width: dimension, height: dimension * 0.42),
                               withAttributes: [.font: NSFont.systemFont(ofSize: dimension * 0.35, weight: .semibold),
                                                .foregroundColor: NSColor.white, .paragraphStyle: style])
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not render app icon")
        }
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed: \(process.terminationStatus)") }
