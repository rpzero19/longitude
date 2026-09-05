import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  LabTextParser.swift — deterministic extraction from report text.
//
//  Runs on every device, with no Apple Intelligence requirement, and is fully
//  testable outside Xcode. The on-device model refines what this can't resolve;
//  it is never the only path to a result.
//
//  Reports are laid out as columns:
//      Haemoglobin        14.2   g/dL      13.0 - 17.0
//      Cholesterol Total  195    mg/dL     < 200
// ─────────────────────────────────────────────────────────────────────────────

public struct ParsedLine: Sendable, Equatable {
    public var name: String
    public var value: Double
    public var unit: String
    public var range: String
}

public enum LabTextParser {

    /// A token that is purely a number, e.g. "14.2" but not "B12".
    static func isNumeric(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        return Double(token) != nil
    }

    /// Splits a value welded to its unit: "1.2mg/dL" into "1.2" and "mg/dL".
    ///
    /// Some labs print no space there. Left joined, the token isn't numeric, so
    /// the parser walks past the real result and takes the next bare number it
    /// finds — which is the interval's lower bound. That records a wrong value
    /// silently, and a wrong value in a health record is far worse than no
    /// value, so this has to be handled rather than skipped.
    ///
    /// Only a genuine number followed by a letter splits: "30-Jul-2026" and
    /// "13.0-17.0" must stay whole.
    static func splitValueFromUnit(_ token: String) -> [String] {
        let digits = token.prefix { $0.isNumber || $0 == "." || $0 == "," }
        guard !digits.isEmpty else { return [token] }
        let rest = token.dropFirst(digits.count)
        guard let head = rest.first, head.isLetter || head == "%" else { return [token] }
        guard Double(digits) != nil else { return [token] }
        return [String(digits), String(rest)]
    }

    /// Marks the start of a reference interval: "<", ">", "13.0-17.0", or a
    /// number that is followed by a dash.
    static func rangeStart(in tokens: [String]) -> Int? {
        for (i, t) in tokens.enumerated() {
            if t.hasPrefix("<") || t.hasPrefix(">") || t.hasPrefix("≤") || t.hasPrefix("≥") {
                return i
            }
            // "13.0-17.0" as a single token: exactly one dash, numbers either side.
            if t.filter({ $0 == "-" }).count == 1,
               let dash = t.firstIndex(of: "-"),
               isNumeric(String(t[t.startIndex..<dash])),
               isNumeric(String(t[t.index(after: dash)...])) {
                return i
            }
            // "13.0 - 17.0" across three tokens.
            if isNumeric(t), i + 1 < tokens.count,
               tokens[i + 1] == "-" || tokens[i + 1] == "–" {
                return i
            }
        }
        return nil
    }

    /// Splits one line into name / value / unit / range.
    ///
    /// The analyte name is found by asking the registry, longest match first.
    /// That resolves names that begin with digits — "25 OH Vitamin D" — which
    /// a "first number is the value" rule would mangle.
    public static func parseLine(_ raw: String) -> ParsedLine? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .flatMap { splitValueFromUnit(String($0)) }
        guard tokens.count >= 2 else { return nil }

        // Walk candidate value positions left to right and let the registry
        // confirm where the name ends.
        //
        // Searching longest-name-first is wrong: the registry tolerates trailing
        // method notes, so "SGPT (ALT) 32 U/L <" also resolves to ALT and would
        // swallow the value, leaving 50 (the range bound) as the result.
        var nameEnd: Int? = nil
        for (i, t) in tokens.enumerated() where i > 0 && isNumeric(t) {
            let candidate = tokens[0..<i].joined(separator: " ")
            if BiomarkerRegistry.match(candidate) != nil { nameEnd = i; break }
        }

        // Unrecognised analyte: fall back to the first standalone number.
        if nameEnd == nil {
            for (i, t) in tokens.enumerated() where i > 0 && isNumeric(t) {
                nameEnd = i
                break
            }
        }

        guard let split = nameEnd, split < tokens.count,
              let value = Double(tokens[split]) else { return nil }

        // "Creatinine : 1.2 mg/dL" — the colon separates the name from the
        // value and is not part of either.
        var nameTokens = Array(tokens[0..<split])
        while let last = nameTokens.last, last == ":" || last == "-" {
            nameTokens.removeLast()
        }
        var name = nameTokens.joined(separator: " ")
        if name.hasSuffix(":") { name = String(name.dropLast()) }
        name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let rest = Array(tokens[(split + 1)...])
        var unitTokens: [String] = []
        var rangeTokens: [String] = []
        if let r = rangeStart(in: rest) {
            unitTokens = Array(rest[0..<r])
            rangeTokens = Array(rest[r...])
        } else {
            unitTokens = rest
        }

        // Labs caption the interval in the same column — "Normal : > 90",
        // "Method:Calculated". A token carrying a colon is a label, not a unit.
        unitTokens.removeAll { $0.contains(":") }

        // Some captions carry no colon at all. These are words, not units, and
        // leaving one in place both mislabels the reading and hides the real
        // unit still sitting at the end of the interval.
        unitTokens.removeAll { captions.contains($0.lowercased()) }

        // Column order is not settled between labs. Plenty print the interval
        // before the unit — "48 <45 U/L" rather than "48 U/L <45" — which
        // strands the unit at the tail of the range and leaves the unit empty.
        // An empty unit then fails looksLikeResult, so the whole line is
        // dropped: one column ordering silently costs an entire report.
        if unitTokens.isEmpty, rangeTokens.count > 1,
           let last = rangeTokens.last, isUnitShaped(last) {
            unitTokens = [rangeTokens.removeLast()]
        }

        let unit = unitTokens.joined(separator: " ")
        let range = rangeTokens.joined(separator: " ")

        return ParsedLine(
            name: name,
            value: value,
            unit: unit.trimmingCharacters(in: .whitespaces),
            range: range.trimmingCharacters(in: .whitespaces))
    }

    /// Parses a whole report, keeping only lines that yield a usable reading.
    public static func parse(_ text: String, date: Date = Date(),
                             reportID: UUID? = nil) -> [Reading] {
        // One PDF often bundles several panels, and a lab that runs albumin
        // for both the liver and the kidney panel prints it on both — same
        // specimen, same value, printed twice. Two identical points on one
        // date is a printing artefact, not a repeated test, so keep the first.
        var seen = Set<String>()
        return text.split(whereSeparator: \.isNewline).compactMap { line -> Reading? in
            guard let parsed = parseLine(String(line)) else { return nil }
            let def = BiomarkerRegistry.match(parsed.name)
            // An unrecognised analyte is kept only when the line still looks
            // like a result. Reports are full of numbers that aren't results —
            // "Page 1 of 2", "Age/Sex: 34 Y / M", phone numbers, addresses —
            // and admitting one of those corrupts the record far worse than
            // dropping an obscure analyte does.
            if def == nil && !looksLikeResult(parsed) { return nil }
            let fingerprint = "\(def?.id ?? parsed.name)|\(parsed.value)|\(parsed.unit)"
            guard seen.insert(fingerprint).inserted else { return nil }
            return Reading(
                biomarkerID: def?.id,
                rawName: parsed.name,
                value: parsed.value,
                unit: parsed.unit,
                canonicalValue: def.flatMap {
                    BiomarkerRegistry.toCanonical(value: parsed.value,
                                                  unit: parsed.unit, for: $0)
                },
                range: ReferenceRange.parse(parsed.range),
                date: date,
                reportID: reportID)
        }
    }

    /// Words labs use to head a reference interval. Never units.
    static let captions: Set<String> = [
        "normal", "desirable", "optimal", "expected", "reference", "ref",
        "target", "therapeutic", "borderline", "adult", "adults", "male",
        "female", "range", "interval", "deficient", "insufficient",
        "sufficient", "not", "established", "applicable",
    ]

    /// A unit carries letters and isn't itself a number. Digits alone don't
    /// disqualify it — "ml/min/1.73m2" and "10^9/L" are units labs really use.
    static func isUnitShaped(_ token: String) -> Bool {
        guard Double(token) == nil, !isNumeric(token) else { return false }
        return token.contains(where: \.isLetter) || token.contains("%")
    }

    /// Heuristics for whether an unrecognised line is plausibly a result.
    static func looksLikeResult(_ p: ParsedLine) -> Bool {
        // Label lines ("Patient:", "Age/Sex:") are never results.
        if p.name.contains(":") { return false }
        if p.name.count > 40 { return false }
        if p.unit.isEmpty { return false }
        // A real unit has no digits in it; "of 2" does.
        if p.unit.contains(where: \.isNumber) { return false }
        // Either the lab printed an interval, or the unit is unit-shaped.
        return ReferenceRange.parse(p.range).isUsable
            || p.unit.contains("/") || p.unit.contains("%")
    }

    /// Finds the collection date on a report. Labs print it many ways, so this
    /// looks for a labelled date first and falls back to any parseable one.
    public static func findDate(in text: String) -> Date? {
        let labels = ["collected", "collection", "sample date", "drawn",
                      "received", "reported", "date"]
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)

        for line in lines {
            let lower = line.lowercased()
            guard labels.contains(where: { lower.contains($0) }) else { continue }
            if let d = firstDate(in: line) { return d }
        }
        for line in lines {
            if let d = firstDate(in: line) { return d }
        }
        return nil
    }

    static let dateFormats = [
        "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
        "yyyy-MM-dd", "MM/dd/yyyy",
        "dd MMM yyyy", "dd-MMM-yyyy", "MMM dd, yyyy", "d MMMM yyyy"
    ]

    static func firstDate(in line: String) -> Date? {
        // Candidate substrings that look like dates.
        let pattern = #"\d{1,4}[\/\-\. ][A-Za-z0-9]{1,9}[\/\-\. ]\d{2,4}"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = line as NSString
        let matches = re.matches(in: line, range: NSRange(location: 0, length: ns.length))

        for m in matches {
            let candidate = ns.substring(with: m.range)
            for format in dateFormats {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = format
                if let d = f.date(from: candidate) {
                    // Reject nonsense: a lab report is never from 1900 or 2200.
                    let year = Calendar(identifier: .gregorian).component(.year, from: d)
                    if year >= 1990 && year <= 2100 { return d }
                }
            }
        }
        return nil
    }
}
