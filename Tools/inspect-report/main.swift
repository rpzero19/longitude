import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

// ─────────────────────────────────────────────────────────────────────────────
//  inspect-report — runs the real parser over a real report and says what it
//  understood. Diagnostics only; it writes nothing and sends nothing anywhere.
//
//  Values are REDACTED by default. Fixing the registry needs analyte names and
//  match outcomes, not your results — so there is no reason to print them.
//  Pass --values to see them (they stay on this machine either way).
// ─────────────────────────────────────────────────────────────────────────────

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("""
    usage: inspect-report <report.pdf | report.txt> [--values] [--text]

      --values   show the actual numbers (default: redacted)
      --text     dump the raw extracted text (implies --values)
    """)
    exit(1)
}
let path = args[1]
let showValues = args.contains("--values") || args.contains("--text")
let dumpText = args.contains("--text")

func redact(_ s: String) -> String {
    showValues ? s : s.map { $0.isNumber ? "•" : $0 }.reduce(into: "") { $0.append($1) }
}
func num(_ d: Double) -> String { showValues ? String(format: "%g", d) : "•••" }

/// Left-pads to a column width. String(format:) with %@ doesn't pad reliably
/// once the text contains non-ASCII.
func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}
func rpad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
}

// ── Read the file ────────────────────────────────────────────────────────────
var text = ""
let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
if url.pathExtension.lowercased() == "pdf" {
    #if canImport(PDFKit)
    guard let doc = PDFDocument(url: url) else {
        print("❌ Could not open the PDF. If it's a scan with no text layer, the app "
            + "would use OCR here — export a text copy and pass that instead.")
        exit(1)
    }
    for i in 0..<doc.pageCount {
        if let p = doc.page(at: i), let s = p.string { text += s + "\n" }
    }
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        print("⚠️  The PDF has no extractable text — it's an image-only scan.")
        print("   In the app this path goes through OCR instead. This tool can't test that;")
        print("   photograph it in the app to exercise that route.")
        exit(1)
    }
    #else
    print("PDFKit unavailable"); exit(1)
    #endif
} else {
    text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

let lines = text.split(whereSeparator: \.isNewline).map(String.init)
print("\n📄 \(url.lastPathComponent) — \(lines.count) lines of text extracted")
if dumpText {
    print(String(repeating: "─", count: 70))
    print(text)
    print(String(repeating: "─", count: 70))
}

// ── Date ─────────────────────────────────────────────────────────────────────
if let d = LabTextParser.findDate(in: text) {
    let f = DateFormatter(); f.dateFormat = "d MMM yyyy"
    print("📅 Collection date read as: \(showValues ? f.string(from: d) : "••••")")
} else {
    print("📅 ⚠️  No collection date found — the app would fall back to today.")
}

// ── What parsed ──────────────────────────────────────────────────────────────
let readings = LabTextParser.parse(text)
let matched = readings.filter { $0.biomarkerID != nil }
let unmatched = readings.filter { $0.biomarkerID == nil }

print("\n✅ \(matched.count) recognised · ⚠️ \(unmatched.count) unrecognised\n")

if !matched.isEmpty {
    print("RECOGNISED")
    print(String(repeating: "─", count: 70))
    for r in matched.sorted(by: { $0.displayName < $1.displayName }) {
        var flags: [String] = []
        if r.unitUnreconciled { flags.append("⚠️ UNIT NOT RECONCILED") }
        if !r.range.isUsable && !r.range.printed.isEmpty { flags.append("⚠️ range unparsed: '\(r.range.printed)'") }
        if r.range.printed.isEmpty { flags.append("no range printed") }
        print("  " + pad(r.displayName, 26) + rpad(num(r.value), 9) + "  "
              + pad(r.unit, 11) + flags.joined(separator: " · "))
        if r.rawName.lowercased() != r.displayName.lowercased() {
            print("      ↳ lab called it: \"\(r.rawName)\"")
        }
    }
}

if !unmatched.isEmpty {
    print("\nUNRECOGNISED — these need aliases adding to Biomarkers.swift")
    print(String(repeating: "─", count: 70))
    for r in unmatched {
        print("  " + pad("\"" + r.rawName + "\"", 34)
              + pad("unit: " + (r.unit.isEmpty ? "—" : r.unit), 20)
              + "range: " + (r.range.printed.isEmpty ? "—" : redact(r.range.printed)))
    }
}

// ── Lines that yielded nothing ───────────────────────────────────────────────
// Most are page furniture, but a missed result hides here too.
let consumed = Set(readings.map(\.rawName))
var skipped: [String] = []
for line in lines {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard t.count > 6, t.contains(where: \.isNumber), t.contains(where: \.isLetter) else { continue }
    if consumed.contains(where: { t.hasPrefix($0) }) { continue }
    skipped.append(t)
}
if !skipped.isEmpty {
    print("\nLINES THAT PRODUCED NOTHING (\(skipped.count))")
    print("Mostly headers and patient details — but check for a missed result.")
    print(String(repeating: "─", count: 70))
    for s in skipped.prefix(30) { print("  \(redact(s))") }
    if skipped.count > 30 { print("  … and \(skipped.count - 30) more") }
}

print("\n" + String(repeating: "═", count: 70))
if unmatched.isEmpty && matched.count > 3 {
    print("Every result was recognised.")
} else {
    print("Send the UNRECOGNISED names and I'll add them to the registry.")
}
print(showValues ? "Values shown." : "Values redacted — pass --values to see them.")
print(String(repeating: "═", count: 70) + "\n")
