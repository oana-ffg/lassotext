import CoreGraphics
import Foundation
import Vision

public enum RecognitionError: LocalizedError {
    case unsupportedLanguage(String)
    case noText

    public var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let language):
            "This Mac’s OCR engine does not support \(language). Choose Automatic or another language."
        case .noText:
            "No text found. Try a larger selection or clearer text. Your clipboard has not changed."
        }
    }
}

/// Vision requests run off the UI actor. Captures stay in memory and are never uploaded.
public actor TextRecognizer {
    public init() {}

    public static func supportedLanguages() throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return try request.supportedRecognitionLanguages()
    }

    public func recognize(_ image: CGImage, language: String? = nil, keepLineBreaks: Bool = true) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        if let language {
            guard supported.contains(language) else { throw RecognitionError.unsupportedLanguage(language) }
            request.recognitionLanguages = [language]
            request.automaticallyDetectsLanguage = false
        } else {
            let preferred = ["en-US", "ro-RO", "da-DK"]
            request.recognitionLanguages = preferred.filter(supported.contains)
                + supported.filter { !preferred.contains($0) }
            request.automaticallyDetectsLanguage = true
        }
        try VNImageRequestHandler(cgImage: image).perform([request])
        // Preserve Vision’s reading order rather than sorting columns into each other.
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: keepLineBreaks ? "\n" : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw RecognitionError.noText }
        return text
    }
}
