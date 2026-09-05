import Foundation
#if canImport(UIKit)
import UIKit
import PDFKit
import Vision
#endif

/// Pulls text out of a PDF or a photograph. Entirely local — PDFKit and Vision
/// both run on device.
public enum TextExtraction {
    #if canImport(UIKit)

    public static func fromPDF(at url: URL) -> String? {
        // Security-scoped access is needed for files chosen outside the app.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { return nil }
        var text = ""
        for i in 0..<doc.pageCount {
            // Not page.string: that returns glyphs in drawing order, which
            // splits a lab report's two columns apart. See PDFLayout.
            if let page = doc.page(at: i) { text += PDFLayout.text(of: page) + "\n" }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    /// OCR. Uses accurate recognition and reconstructs lines by vertical
    /// position, because a lab report's meaning lives in its columns.
    public static func fromImage(_ image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                guard let obs = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil); return
                }
                // Group observations into rows by their vertical midpoint.
                var rows: [(y: CGFloat, pieces: [(x: CGFloat, s: String)])] = []
                for o in obs {
                    guard let top = o.topCandidates(1).first else { continue }
                    let y = o.boundingBox.midY
                    let x = o.boundingBox.minX
                    if let idx = rows.firstIndex(where: { abs($0.y - y) < 0.012 }) {
                        rows[idx].pieces.append((x, top.string))
                    } else {
                        rows.append((y, [(x, top.string)]))
                    }
                }
                let text = rows
                    .sorted { $0.y > $1.y }                       // top of page first
                    .map { $0.pieces.sorted { $0.x < $1.x }
                                    .map(\.s).joined(separator: "  ") }
                    .joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false   // don't "correct" analyte names
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        }
    }
    #endif
}
