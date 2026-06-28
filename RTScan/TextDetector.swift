import Vision
import CoreImage

/// Runs Vision text recognition on camera frames and emits candidate
/// title strings (filtered to drop short/noisy fragments).
final class TextDetector {
    private let request: VNRecognizeTextRequest

    init() {
        request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
    }

    /// Returns candidate title strings detected in the given pixel buffer,
    /// longest/most-prominent first.
    func detectCandidates(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [String] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results else { return [] }

        let candidates = observations.compactMap { observation -> (String, Float)? in
            guard let top = observation.topCandidates(1).first else { return nil }
            return (top.string, top.confidence)
        }

        return candidates
            .filter { isLikelyTitle($0.0) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private func isLikelyTitle(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 60 else { return false }
        // Drop strings that are mostly digits/symbols (e.g. timestamps, episode counts).
        let letters = trimmed.filter { $0.isLetter }
        guard Double(letters.count) / Double(trimmed.count) > 0.5 else { return false }
        // Drop common Netflix UI chrome words that aren't titles.
        let blocklist = ["episodes", "season", "play", "more info", "my list", "trailer", "continue watching"]
        let lower = trimmed.lowercased()
        if blocklist.contains(where: { lower == $0 }) { return false }
        return true
    }
}
