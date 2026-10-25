import AppKit

/// A crisp template version of the app's lasso and text, drawn at native scale.
@MainActor
enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let lasso = NSBezierPath()
            lasso.move(to: NSPoint(x: 13.3, y: 3.6))
            lasso.curve(to: NSPoint(x: 15.6, y: 8.7), controlPoint1: NSPoint(x: 15.7, y: 4.6), controlPoint2: NSPoint(x: 15.8, y: 6.4))
            lasso.curve(to: NSPoint(x: 13.9, y: 14.9), controlPoint1: NSPoint(x: 15.6, y: 12.1), controlPoint2: NSPoint(x: 15.6, y: 13.8))
            lasso.curve(to: NSPoint(x: 4.3, y: 15.0), controlPoint1: NSPoint(x: 11.8, y: 16.5), controlPoint2: NSPoint(x: 6.2, y: 16.1))
            lasso.curve(to: NSPoint(x: 2.2, y: 8.0), controlPoint1: NSPoint(x: 2.1, y: 13.8), controlPoint2: NSPoint(x: 2.0, y: 10.8))
            lasso.curve(to: NSPoint(x: 4.1, y: 3.6), controlPoint1: NSPoint(x: 2.3, y: 5.6), controlPoint2: NSPoint(x: 2.8, y: 4.2))
            lasso.curve(to: NSPoint(x: 12.0, y: 3.3), controlPoint1: NSPoint(x: 6.1, y: 2.6), controlPoint2: NSPoint(x: 9.7, y: 2.9))
            lasso.curve(to: NSPoint(x: 16.6, y: 1.4), controlPoint1: NSPoint(x: 14.8, y: 4.7), controlPoint2: NSPoint(x: 17.1, y: 4.1))
            lasso.lineWidth = 1.45
            lasso.lineCapStyle = .round
            lasso.lineJoinStyle = .round
            lasso.stroke()
            let text = NSBezierPath()
            for (y, end) in [(11.8, 11.9), (9.0, 10.9), (6.2, 9.4)] {
                text.move(to: NSPoint(x: 5.8, y: y))
                text.line(to: NSPoint(x: end, y: y))
            }
            text.lineWidth = 1.35
            text.lineCapStyle = .round
            text.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
