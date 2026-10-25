import AppKit
import ScreenCaptureKit

struct CapturedDisplay {
    let screen: NSScreen
    let image: CGImage
}

@MainActor
enum ScreenCapture {
    static func captureDisplays() async throws -> [CapturedDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var captures: [CapturedDisplay] = []
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else {
                throw CaptureError.displayUnavailable
            }
            let configuration = SCStreamConfiguration()
            configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
            configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
            configuration.showsCursor = false
            configuration.captureResolution = .best
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            captures.append(CapturedDisplay(screen: screen, image: image))
        }
        guard !captures.isEmpty else { throw CaptureError.displayUnavailable }
        return captures
    }
}

enum CaptureError: LocalizedError {
    case displayUnavailable
    case cropFailed
    var errorDescription: String? {
        switch self {
        case .displayUnavailable: "A display changed or became unavailable. Please try capturing again."
        case .cropFailed: "The selected area could not be captured. Please try again."
        }
    }
}
