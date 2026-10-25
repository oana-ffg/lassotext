import CoreGraphics
import Foundation
import ImageIO

// Derive every macOS icon size from the single original artwork.
guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift make-icon.swift SOURCE.png OUTPUT.icns\n", stderr)
    exit(2)
}
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil),
      artwork.width == artwork.height, artwork.width >= 1024 else {
    fputs("Icon artwork must be a readable square image at least 1024 pixels wide.\n", stderr)
    exit(1)
}
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
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels, height: pixels,
                                      bitsPerComponent: 8, bytesPerRow: pixels * 4,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            fputs("Could not allocate \(pixels)-pixel icon bitmap.\n", stderr)
            exit(1)
        }
        context.interpolationQuality = .high
        context.draw(artwork, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let suffix = scale == 2 ? "@2x" : ""
        let destination = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        guard let image = context.makeImage(),
              let writer = CGImageDestinationCreateWithURL(destination as CFURL, "public.png" as CFString, 1, nil) else {
            fputs("Could not create \(destination.lastPathComponent).\n", stderr)
            exit(1)
        }
        CGImageDestinationAddImage(writer, image, nil)
        guard CGImageDestinationFinalize(writer) else {
            fputs("Could not write \(destination.lastPathComponent).\n", stderr)
            exit(1)
        }
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fputs("iconutil failed: \(process.terminationStatus)\n", stderr)
    exit(1)
}
