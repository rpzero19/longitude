import Foundation
#if canImport(PDFKit)
import PDFKit
import CoreGraphics

/// Rebuilds a PDF page's visual rows from glyph positions.
///
/// `PDFPage.string` returns text in whatever order the PDF happens to draw it.
/// For the two-column layout every pathology lab uses, that means the entire
/// name column arrives before the entire value column, so each result ends up
/// separated from its own name — sometimes by dozens of lines, sometimes
/// ahead of it. A name without its value is unparseable, and a value without
/// its name is worse than useless.
///
/// So do for PDFs exactly what the OCR path already does for photographs:
/// read the glyph boxes and reassemble the rows the way the page looks.
public enum PDFLayout {

    public static func text(of page: PDFPage) -> String {
        let glyphs = glyphs(of: page)
        guard !glyphs.isEmpty else { return page.string ?? "" }

        let bands = bands(from: glyphs)
        guard !bands.isEmpty else { return page.string ?? "" }

        var rows = [[Glyph]](repeating: [], count: bands.count)
        for g in glyphs { rows[nearestBand(to: g, in: bands)].append(g) }

        // PDF coordinates put the origin at the bottom left, so the top of the
        // page is the largest y. Bands are built in that order already.
        return rows.map(line(from:))
                   .filter { !$0.isEmpty }
                   .joined(separator: "\n")
    }

    private struct Glyph {
        let ch: Character
        let box: CGRect
    }

    /// A band is one visual row: the vertical extent of the ordinary letters
    /// sitting on a shared baseline.
    private struct Band {
        var low: CGFloat
        var high: CGFloat
        var height: CGFloat { high - low }
    }

    private static func glyphs(of page: PDFPage) -> [Glyph] {
        let glyphCount = page.numberOfCharacters
        guard glyphCount > 0, let raw = page.string else { return [] }

        // A newline takes a slot in `string` but draws nothing, so it has no
        // entry in the bounds array — ask for character i directly and every
        // line break shifts the answer one place further out. Walk a separate
        // cursor that only advances on glyphs that were actually drawn.
        var out: [Glyph] = []
        var cursor = 0
        for ch in raw {
            if ch.isNewline { continue }
            defer { cursor += 1 }
            guard cursor < glyphCount else { break }
            let box = page.characterBounds(at: cursor)
            // Neither dimension can be used to decide what counts as a glyph:
            // spaces report zero height, and hyphens can report zero width.
            guard !box.isNull else { continue }
            out.append(Glyph(ch: ch, box: box))
        }
        return out
    }

    /// Groups full-height glyphs into rows by how much they overlap vertically.
    ///
    /// No single coordinate identifies a row. Baselines look promising until a
    /// descender arrives: the "p" in "Phosphatase" starts below the baseline,
    /// so matching on the box bottom gives it a row of its own and splits the
    /// word. Tops fail on x-height letters for the mirror reason. Overlap is
    /// the property that actually holds — every glyph on a line shares most of
    /// its vertical extent with its neighbours, and shares none with the line
    /// above or below.
    private static func bands(from glyphs: [Glyph]) -> [Band] {
        let heights = glyphs.map(\.box.height).filter { $0 > 0 }.sorted()
        guard !heights.isEmpty else { return [] }
        let typical = heights[heights.count / 2]

        var bands: [Band] = []
        for g in glyphs where g.box.height >= typical * 0.7 {
            let box = g.box
            var bestIndex: Int?
            var bestOverlap: CGFloat = 0
            for (i, b) in bands.enumerated() {
                let overlap = Swift.min(b.high, box.maxY) - Swift.max(b.low, box.minY)
                if overlap > bestOverlap { bestOverlap = overlap; bestIndex = i }
            }
            if let i = bestIndex, bestOverlap > box.height * 0.5 {
                bands[i].low = Swift.min(bands[i].low, box.minY)
                bands[i].high = Swift.max(bands[i].high, box.maxY)
            } else {
                bands.append(Band(low: box.minY, high: box.maxY))
            }
        }
        return bands.sorted { $0.low > $1.low }
    }

    /// Every glyph goes somewhere. A character that belongs to no band — a
    /// stray hyphen, a superscript — joins the band it is closest to rather
    /// than being dropped, because dropping the hyphen from "10-71" turns one
    /// reference interval into two meaningless numbers.
    private static func nearestBand(to g: Glyph, in bands: [Band]) -> Int {
        let y = g.box.midY
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (i, b) in bands.enumerated() {
            let d = Swift.max(b.low - y, y - b.high, 0)
            if d < bestDistance { bestDistance = d; best = i }
            if d == 0 { break }
        }
        return best
    }

    /// Glyphs carry no spaces of their own — a space in a PDF is often just a
    /// gap. Anything wider than a fraction of the line height is a word break;
    /// the wide gutter between columns collapses to a single space, which is
    /// all the parser needs.
    private static func line(from glyphs: [Glyph]) -> String {
        let sorted = glyphs.sorted { $0.box.minX < $1.box.minX }
        let height = sorted.map(\.box.height).max() ?? 0
        var out = ""
        var previousMaxX: CGFloat?
        for g in sorted {
            if let prev = previousMaxX, g.box.minX - prev > height * 0.28,
               !out.hasSuffix(" ") {
                out.append(" ")
            }
            out.append(g.ch)
            previousMaxX = Swift.max(previousMaxX ?? g.box.maxX, g.box.maxX)
        }
        return out.trimmingCharacters(in: .whitespaces)
    }
}
#endif
