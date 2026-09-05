import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  ManualEntry.swift — building and correcting a reading by hand.
//
//  Parsing will always meet a lab it has never seen. Without a way to type a
//  result in, an unreadable report means the app is simply broken for that
//  person; with one, it degrades to a chore. This is also the correction path:
//  a misread value is fixed here rather than silently kept.
//
//  Kept free of SwiftUI so it can be tested without Xcode, like the parser.
// ─────────────────────────────────────────────────────────────────────────────

public enum ManualEntry {

    /// Builds a reading from typed fields, resolving the analyte and unit the
    /// same way the parser does — so a hand-entered result joins the same
    /// timeline as an imported one instead of starting a parallel series.
    public static func reading(name: String,
                               value: Double,
                               unit: String,
                               rangeText: String,
                               date: Date,
                               id: UUID = UUID(),
                               reportID: UUID? = nil) -> Reading? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let def = BiomarkerRegistry.match(trimmedName)
        return Reading(
            id: id,
            biomarkerID: def?.id,
            rawName: trimmedName,
            value: value,
            unit: trimmedUnit,
            canonicalValue: def.flatMap {
                BiomarkerRegistry.toCanonical(value: value, unit: trimmedUnit, for: $0)
            },
            range: ReferenceRange.parse(rangeText),
            date: date,
            reportID: reportID)
    }

    /// Re-resolves an edited reading, keeping its identity and report so an
    /// edit updates the row in place rather than adding a second one.
    public static func edited(_ original: Reading,
                              name: String,
                              value: Double,
                              unit: String,
                              rangeText: String) -> Reading? {
        reading(name: name, value: value, unit: unit, rangeText: rangeText,
                date: original.date, id: original.id, reportID: original.reportID)
    }

    /// Accepts what people actually type: "1.2", "1,2", " 1.2 ".
    public static func number(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                          .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}
