import AppKit
import LassoCore

@MainActor
public final class SelectionOverlay {
    private var windows: [NSWindow] = []
    private var completion: ((Result<CGImage?, Error>) -> Void)?

    public init() {}

    public func show(_ displays: [CapturedDisplay], completion: @escaping (Result<CGImage?, Error>) -> Void) {
        self.completion = completion
        for display in displays {
            let window = SelectionWindow(contentRect: display.screen.frame, styleMask: .borderless,
                                         backing: .buffered, defer: false)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.isOpaque = true
            window.hasShadow = false
            window.contentView = SelectionView(image: display.image) { [weak self] result in self?.finish(result) }
            windows.append(window)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        let mouse = NSEvent.mouseLocation
        let activeWindow = windows.first { $0.frame.contains(mouse) } ?? windows.first
        activeWindow?.makeKey()
        activeWindow?.makeFirstResponder(activeWindow?.contentView)
    }

    public func cancel() { finish(.success(nil)) }

    private func finish(_ result: Result<CGImage?, Error>) {
        guard let completion else { return }
        self.completion = nil
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
        completion(result)
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
class SelectionView: NSView {
    private let image: CGImage
    private let backgroundImage: NSImage
    private let completion: (Result<CGImage?, Error>) -> Void
    private var start: NSPoint?
    private var current: NSPoint?

    init(image: CGImage, completion: @escaping (Result<CGImage?, Error>) -> Void) {
        self.image = image
        backgroundImage = NSImage(cgImage: image, size: .zero)
        self.completion = completion
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        backgroundImage.draw(in: bounds)
        let mask = NSBezierPath(rect: bounds)
        if let selection {
            mask.appendRect(selection)
            mask.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.32).setFill()
        mask.fill()
        if let selection {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
        }
        let text = "Drag to copy text  •  Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let box = NSRect(x: bounds.midX - (size.width + 32) / 2, y: bounds.maxY - 92,
                         width: size.width + 32, height: size.height + 24)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12).fill()
        text.draw(at: NSPoint(x: box.minX + 16, y: box.minY + 12), withAttributes: attributes)
    }

    private var selection: NSRect? {
        guard let start, let current else { return nil }
        return NSRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(current.x - start.x), height: abs(current.y - start.y))
            .intersection(bounds)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        let previous = selection
        start = convert(event.locationInWindow, from: nil)
        current = start
        invalidateSelection(previous: previous)
    }

    override func mouseDragged(with event: NSEvent) {
        let previous = selection
        current = convert(event.locationInWindow, from: nil)
        invalidateSelection(previous: previous)
    }

    private func invalidateSelection(previous: NSRect?) {
        let next = selection
        guard previous != next else { return }
        // Restore the old outline and reveal the new selection. AppKit clips
        // drawing to this region; the rest of the frozen display is unchanged.
        let dirty = (previous ?? .null).union(next ?? .null)
        guard !dirty.isNull else { return }
        setNeedsDisplay(dirty.insetBy(dx: -2, dy: -2).integral.intersection(bounds))
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let selection,
              let crop = SelectionGeometry.pixelRect(selection: selection, viewSize: bounds.size,
                                                     imageSize: CGSize(width: image.width, height: image.height)) else {
            completion(.success(nil))
            return
        }
        guard let image = image.cropping(to: crop) else { completion(.failure(CaptureError.cropFailed)); return }
        completion(.success(image))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { completion(.success(nil)) }
    }

    override func rightMouseDown(with event: NSEvent) { completion(.success(nil)) }
}
