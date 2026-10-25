import AppKit
import LassoCore
import Testing

struct RecognitionTests {
    @Test(arguments: [
        ("en-US", "The quick brown fox jumps over the lazy dog."),
        ("ro-RO", "În România, șase studenți învață limba română."),
        ("da-DK", "Rødgrød med fløde. Æble, øl og blåbær."),
    ])
    @MainActor func readsLanguageAndAutomatic(sample: (String, String)) async throws {
        let supported = try TextRecognizer.supportedLanguages()
        try #require(supported.contains(sample.0), "This OS must support the three primary languages")
        for dark in [false, true] {
            let image = try render(sample.1, dark: dark)
            let recognizer = TextRecognizer()
            let explicit = try await recognizer.recognize(image, language: sample.0)
            #expect(explicit == sample.1)
            let automatic = try await recognizer.recognize(image)
            #expect(automatic == sample.1)
        }
    }

    @Test @MainActor func preservesOrFlattensLines() async throws {
        let image = try render("First line of text.\nSecond line of text.")
        let recognizer = TextRecognizer()
        #expect(try await recognizer.recognize(image, language: "en-US") == "First line of text.\nSecond line of text.")
        #expect(try await recognizer.recognize(image, language: "en-US", keepLineBreaks: false)
                == "First line of text. Second line of text.")
    }

    @Test @MainActor func rejectsBlankAndUnsupportedLanguage() async throws {
        let image = try render("")
        let recognizer = TextRecognizer()
        await #expect(throws: RecognitionError.self) { try await recognizer.recognize(image) }
        await #expect(throws: RecognitionError.self) { try await recognizer.recognize(image, language: "invalid") }
    }

    @MainActor private func render(_ text: String, dark: Bool = false) throws -> CGImage {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1500, pixelsHigh: 300,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        (dark ? NSColor.black : NSColor.white).setFill()
        NSRect(x: 0, y: 0, width: 1500, height: 300).fill()
        (text as NSString).draw(in: NSRect(x: 40, y: 35, width: 1420, height: 220), withAttributes: [
            .font: NSFont.systemFont(ofSize: 42), .foregroundColor: dark ? NSColor.white : NSColor.black,
        ])
        NSGraphicsContext.restoreGraphicsState()
        return try #require(bitmap.cgImage)
    }
}
