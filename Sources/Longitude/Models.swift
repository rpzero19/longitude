import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  Models.swift — plain Codable value types, stored on device only.
// ─────────────────────────────────────────────────────────────────────────────

/// The interval printed on the report itself. We never substitute our own:
/// reference intervals are assay- and lab-specific, and swapping in a generic
/// one would silently change whether a result reads as normal.
public struct ReferenceRange: Codable, Sendable, Equatable {
    public var low: Double?
    public var high: Double?
    /// Exactly as printed, e.g. "13.0 - 17.0" or "< 200".
    public var printed: String

    public init(low: Double? = nil, high: Double? = nil, printed: String = "") {
        self.low = low
        self.high = high
        self.printed = printed
    }

    public var isUsable: Bool { low != nil || high != nil }

    /// Parses the forms labs actually print. Returns a range with whatever
    /// bounds it could establish; an unparseable string still keeps `printed`
    /// so the user sees what the lab said.
    public static func parse(_ text: String) -> ReferenceRange {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return ReferenceRange() }

        // Normalise the several dash characters labs use.
        let cleaned = raw
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            // Space-delimited: an unqualified "to" would mangle "Total".
            .replacingOccurrences(of: " to ", with: " - ", options: .caseInsensitive)
            .replacingOccurrences(of: "≤", with: "<=")
            .replacingOccurrences(of: "≥", with: ">=")
            // Some labs typewrite the symbol: ">/=" for "≥".
            .replacingOccurrences(of: ">/=", with: ">=")
            .replacingOccurrences(of: "</=", with: "<=")

        func number(_ s: String) -> Double? {
            Double(s.trimmingCharacters(in: CharacterSet(charactersIn: " <>=").union(.whitespaces)))
        }

        // "< 200" / "<= 200" — upper bound only.
        if cleaned.hasPrefix("<") {
            return ReferenceRange(low: nil, high: number(cleaned), printed: raw)
        }
        // "> 40" / ">= 40" — lower bound only.
        if cleaned.hasPrefix(">") {
            return ReferenceRange(low: number(cleaned), high: nil, printed: raw)
        }
        // "13.0 - 17.0". Split on a dash that isn't a leading minus sign.
        let parts = cleaned.dropFirst().split(separator: "-", maxSplits: 1,
                                              omittingEmptySubsequences: false)
        if parts.count == 2 {
            let lowText = String(cleaned.prefix(1)) + parts[0]
            if let lo = number(lowText), let hi = number(String(parts[1])), lo <= hi {
                return ReferenceRange(low: lo, high: hi, printed: raw)
            }
        }
        return ReferenceRange(printed: raw)
    }
}

/// Where a reading sits relative to the printed interval. This is arithmetic,
/// not interpretation — the app states the comparison and stops there.
public enum RangeStatus: String, Codable, Sendable {
    case within, below, above, unknown

    public var label: String {
        switch self {
        case .within:  return "Within range"
        case .below:   return "Below range"
        case .above:   return "Above range"
        case .unknown: return "No range given"
        }
    }
}

public struct Reading: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    /// Registry id once resolved; nil when the analyte wasn't recognised.
    public var biomarkerID: String?
    /// The label exactly as the lab printed it — always preserved, so an
    /// unrecognised analyte is still visible rather than discarded.
    public var rawName: String
    public var value: Double
    public var unit: String
    /// Value converted into the registry's canonical unit, when possible.
    public var canonicalValue: Double?
    public var range: ReferenceRange
    public var date: Date
    public var reportID: UUID?

    public init(id: UUID = UUID(), biomarkerID: String? = nil, rawName: String,
                value: Double, unit: String, canonicalValue: Double? = nil,
                range: ReferenceRange = ReferenceRange(), date: Date = Date(),
                reportID: UUID? = nil) {
        self.id = id
        self.biomarkerID = biomarkerID
        self.rawName = rawName
        self.value = value
        self.unit = unit
        self.canonicalValue = canonicalValue
        self.range = range
        self.date = date.storagePrecision
        self.reportID = reportID
    }

    public var definition: BiomarkerDef? {
        biomarkerID.flatMap { BiomarkerRegistry.definition(id: $0) }
    }

    public var displayName: String { definition?.name ?? rawName }

    /// Compared against the lab's own printed interval, never a substituted one.
    public var status: RangeStatus {
        guard range.isUsable else { return .unknown }
        if let hi = range.high, value > hi { return .above }
        if let lo = range.low, value < lo { return .below }
        return .within
    }

    /// Value to plot: canonical where units could be reconciled, else raw.
    public var plottedValue: Double { canonicalValue ?? value }

    /// True when the unit couldn't be reconciled, so this point may not be
    /// comparable with the rest of the series.
    public var unitUnreconciled: Bool {
        definition != nil && canonicalValue == nil && !unit.isEmpty
    }
}

public struct LabReport: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var date: Date
    public var labName: String
    /// Original PDF or image, kept in the app's container so the user can
    /// always check a value against the source document.
    public var sourceFilename: String?
    public var importedAt: Date

    public init(id: UUID = UUID(), date: Date = Date(), labName: String = "",
                sourceFilename: String? = nil, importedAt: Date = Date()) {
        self.id = id
        self.date = date.storagePrecision
        self.labName = labName
        self.sourceFilename = sourceFilename
        self.importedAt = importedAt.storagePrecision
    }
}

public struct AppData: Codable, Sendable, Equatable {
    public var reports: [LabReport]
    public var readings: [Reading]
    public var schemaVersion: Int

    public init(reports: [LabReport] = [], readings: [Reading] = [], schemaVersion: Int = 1) {
        self.reports = reports
        self.readings = readings
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Series

/// One analyte's history, ready to chart.
public struct Series: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let panel: Panel
    public let unit: String
    public let readings: [Reading]      // ascending by date
    public let higherIsBetter: Bool

    public var latest: Reading? { readings.last }
    public var previous: Reading? { readings.count >= 2 ? readings[readings.count - 2] : nil }

    /// Change since the previous reading, in canonical units.
    public var delta: Double? {
        guard let l = latest, let p = previous else { return nil }
        return l.plottedValue - p.plottedValue
    }

    public var percentChange: Double? {
        guard let l = latest, let p = previous, p.plottedValue != 0 else { return nil }
        return (l.plottedValue - p.plottedValue) / abs(p.plottedValue) * 100
    }

    /// True when any point's units couldn't be reconciled — the chart then
    /// carries a caveat rather than pretending the line is comparable.
    public var hasUnreconciledUnits: Bool { readings.contains { $0.unitUnreconciled } }
}

public enum SeriesBuilder {

    /// Groups readings into per-analyte series. Unrecognised analytes are
    /// grouped by their raw name so nothing is silently dropped.
    public static func build(from readings: [Reading]) -> [Series] {
        var buckets: [String: [Reading]] = [:]
        for r in readings {
            let key = r.biomarkerID ?? "raw:" + BiomarkerRegistry.normalise(r.rawName)
            buckets[key, default: []].append(r)
        }

        return buckets.compactMap { key, group -> Series? in
            let sorted = group.sorted { $0.date < $1.date }
            guard let first = sorted.first else { return nil }
            if let def = first.definition {
                return Series(id: def.id, name: def.name, panel: def.panel,
                              unit: def.canonicalUnit, readings: sorted,
                              higherIsBetter: def.higherIsBetter)
            }
            return Series(id: key, name: first.rawName, panel: .metabolic,
                          unit: first.unit, readings: sorted, higherIsBetter: false)
        }
        .sorted { $0.name < $1.name }
    }
}
