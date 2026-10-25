import CoreGraphics

public enum SelectionGeometry {
    /// AppKit is bottom-up in points; a captured bitmap is top-down in pixels.
    public static func pixelRect(selection: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: viewSize))
        guard !clipped.isNull, clipped.width >= 3, clipped.height >= 3 else { return nil }
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height
        return CGRect(
            x: clipped.minX * scaleX,
            y: (viewSize.height - clipped.maxY) * scaleY,
            width: clipped.width * scaleX,
            height: clipped.height * scaleY
        ).integral.intersection(CGRect(origin: .zero, size: imageSize))
    }
}
