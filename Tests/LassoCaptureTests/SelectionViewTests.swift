import AppKit
@testable import LassoCapture
import Testing

@Suite(.serialized)
@MainActor
struct SelectionViewTests {
    @Test func dragInvalidatesOnlyTheSelectionArea() throws {
        // A 4K display and 1,000 delivered drag events. No window or screen capture.
        let view = RecordingSelectionView(image: try image(width: 3840, height: 2160)) { _ in }
        view.frame.size = NSSize(width: 3840, height: 2160)
        view.mouseDown(with: try mouse(.leftMouseDown, at: NSPoint(x: 100, y: 100)))
        view.invalidations.removeAll()
        for index in 0..<1000 {
            view.mouseDragged(with: try mouse(.leftMouseDragged,
                at: NSPoint(x: 200 + index % 101, y: 200 + index % 61)))
        }
        let area = view.invalidations.reduce(0) { $0 + $1.width * $1.height }
        print("Drag invalidation: events=1000 rects=\(view.invalidations.count) area=\(Int(area)) square points")
        #expect(view.invalidations.count == 1000)
        #expect(area < view.bounds.width * view.bounds.height * 1000 / 100,
                "Small selections must not repaint the entire 4K display on every event")

        view.invalidations.removeAll()
        let lastPoint = NSPoint(x: 200 + 999 % 101, y: 200 + 999 % 61)
        for _ in 0..<1000 {
            view.mouseDragged(with: try mouse(.leftMouseDragged, at: lastPoint))
        }
        #expect(view.invalidations.count == 0, "Repeated positions do not change any pixels")
    }

    @Test(arguments: [1, 2])
    func partialRedrawMatchesFullRedraw(scale: Int) throws {
        let size = NSSize(width: 320, height: 240)
        let view = RecordingSelectionView(image: try image(width: 320 * scale, height: 240 * scale)) { _ in }
        view.frame.size = size
        let incremental = try bitmap(width: 320 * scale, height: 240 * scale)
        draw(view, into: incremental, scale: scale, rects: [view.bounds])

        // All drag directions, fractional coordinates, edges, zero-sized selections,
        // and the instruction box. The previous outline must be erased each time.
        for start in [NSPoint(x: 160, y: 120), NSPoint(x: 2, y: 238)] {
            view.invalidations.removeAll()
            view.mouseDown(with: try mouse(.leftMouseDown, at: start))
            draw(view, into: incremental, scale: scale, rects: view.invalidations)
            for point in [NSPoint(x: 250.5, y: 200.5), NSPoint(x: 20, y: 30),
                          NSPoint(x: 260, y: 25), NSPoint(x: 15, y: 220),
                          NSPoint(x: -10, y: 260), start] {
                view.invalidations.removeAll()
                view.mouseDragged(with: try mouse(.leftMouseDragged, at: point))
                draw(view, into: incremental, scale: scale, rects: view.invalidations)
                let full = try bitmap(width: 320 * scale, height: 240 * scale)
                draw(view, into: full, scale: scale, rects: [view.bounds])
                #expect(bytes(incremental) == bytes(full), "Dirty-region drawing must match a full repaint")
            }
        }
    }

    @Test func croppingAndCancellationKeepTheirBehavior() throws {
        var result: Result<CGImage?, Error>?
        let view = RecordingSelectionView(image: try image(width: 640, height: 480)) { result = $0 }
        view.frame.size = NSSize(width: 320, height: 240)
        view.mouseDown(with: try mouse(.leftMouseDown, at: NSPoint(x: 120, y: 100)))
        view.mouseUp(with: try mouse(.leftMouseUp, at: NSPoint(x: 20, y: 30)))
        let crop = try #require(try result?.get())
        #expect(crop.width == 200)
        #expect(crop.height == 140)

        result = nil
        view.mouseDown(with: try mouse(.leftMouseDown, at: NSPoint(x: 20, y: 30)))
        view.mouseUp(with: try mouse(.leftMouseUp, at: NSPoint(x: 21, y: 31)))
        #expect(try #require(result).get() == nil)
        result = nil
        view.rightMouseDown(with: try mouse(.rightMouseDown, at: .zero))
        #expect(try #require(result).get() == nil)
        result = nil
        let escape = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        view.keyDown(with: escape)
        #expect(try #require(result).get() == nil)
    }

    private func mouse(_ type: NSEvent.EventType, at point: NSPoint) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func bitmap(width: Int, height: Int) throws -> NSBitmapImageRep {
        try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32))
    }

    private func image(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 0.85, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0.2, alpha: 1))
        context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        return try #require(context.makeImage())
    }

    private func draw(_ view: NSView, into bitmap: NSBitmapImageRep, scale: Int, rects: [NSRect]) {
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        for rect in rects {
            context.cgContext.saveGState()
            context.cgContext.clip(to: rect)
            view.draw(rect)
            context.cgContext.restoreGState()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func bytes(_ bitmap: NSBitmapImageRep) -> Data {
        Data(bytes: bitmap.bitmapData!, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }
}

@MainActor
private final class RecordingSelectionView: SelectionView {
    var invalidations: [NSRect] = []

    override func setNeedsDisplay(_ invalidRect: NSRect) {
        invalidations.append(invalidRect.intersection(bounds))
        super.setNeedsDisplay(invalidRect)
    }
}
