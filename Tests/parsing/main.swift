import Foundation

var passed = 0, failed = 0
func ok(_ n: String, _ c: Bool) {
    if c { passed += 1; print("  ✅ \(n)") } else { failed += 1; print("  ❌ \(n)") }
}
func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
}

// ── Reference ranges, as labs actually print them ────────────────────────────
print("\n▸ Reference range parsing")
func rng(_ s: String) -> ReferenceRange { ReferenceRange.parse(s) }

ok("'13.0 - 17.0'",        rng("13.0 - 17.0").low == 13 && rng("13.0 - 17.0").high == 17)
ok("en dash '13.0 – 17.0'", rng("13.0 – 17.0").low == 13 && rng("13.0 – 17.0").high == 17)
ok("no spaces '13-17'",    rng("13-17").low == 13 && rng("13-17").high == 17)
ok("'70 to 100'",          rng("70 to 100").low == 70 && rng("70 to 100").high == 100)
ok("'< 200' → upper only", rng("< 200").high == 200 && rng("< 200").low == nil)
ok("'<200' no space",      rng("<200").high == 200)
ok("'≤ 200' unicode",      rng("≤ 200").high == 200)
ok("'> 40' → lower only",  rng("> 40").low == 40 && rng("> 40").high == nil)
ok("'≥ 40' unicode",       rng("≥ 40").low == 40)
ok("negative lower bound '-2.0 - 2.0'",
   rng("-2.0 - 2.0").low == -2 && rng("-2.0 - 2.0").high == 2)
ok("empty string is unusable",     !rng("").isUsable)
ok("'Negative' is unusable",       !rng("Negative").isUsable)
ok("but 'Negative' is still shown", rng("Negative").printed == "Negative")
ok("word containing 'to' survives", rng("Total < 200").printed == "Total < 200")

// ── Status is arithmetic, not interpretation ─────────────────────────────────
print("\n▸ Range comparison")
func reading(_ v: Double, _ r: String) -> Reading {
    Reading(rawName: "Test", value: v, unit: "", range: rng(r))
}
ok("14 in 13-17 → within",  reading(14, "13 - 17").status == .within)
ok("12 in 13-17 → below",   reading(12, "13 - 17").status == .below)
ok("18 in 13-17 → above",   reading(18, "13 - 17").status == .above)
ok("boundary 13 → within",  reading(13, "13 - 17").status == .within)
ok("boundary 17 → within",  reading(17, "13 - 17").status == .within)
ok("190 with '< 200' → within", reading(190, "< 200").status == .within)
ok("210 with '< 200' → above",  reading(210, "< 200").status == .above)
ok("no printed range → unknown", reading(14, "").status == .unknown)

// ── Series: the whole point of the app ───────────────────────────────────────
print("\n▸ Series grouping across years and namings")
func mk(_ raw: String, _ v: Double, _ unit: String, _ date: Date) -> Reading {
    let def = BiomarkerRegistry.match(raw)
    return Reading(
        biomarkerID: def?.id, rawName: raw, value: v, unit: unit,
        canonicalValue: def.flatMap {
            BiomarkerRegistry.toCanonical(value: v, unit: unit, for: $0) },
        range: ReferenceRange(), date: date)
}

let mixed = [
    mk("SGPT", 32, "U/L",  day(2021, 3, 4)),
    mk("ALT",  41, "IU/L", day(2023, 8, 19)),
    mk("Alanine Aminotransferase", 28, "U/L", day(2025, 1, 7)),
    mk("Total Cholesterol", 5.2, "mmol/L", day(2021, 3, 4)),
    mk("Cholesterol - Total (CHOD-PAP)", 195, "mg/dL", day(2025, 1, 7)),
]
let series = SeriesBuilder.build(from: mixed)

ok("three ALT namings collapse to one series",
   series.filter { $0.id == "alt" }.count == 1)
ok("that series holds all three readings",
   series.first { $0.id == "alt" }?.readings.count == 3)
ok("readings are ordered oldest → newest",
   series.first { $0.id == "alt" }.map { s in
       zip(s.readings, s.readings.dropFirst()).allSatisfy { $0.date <= $1.date }
   } == true)
ok("two cholesterol namings collapse to one series",
   series.filter { $0.id == "chol" }.count == 1)

let cholSeries = series.first { $0.id == "chol" }!
ok("mmol/L converted so the line is comparable",
   abs((cholSeries.readings.first?.plottedValue ?? 0) - 201.08) < 0.5)
ok("mg/dL reading left untouched",
   cholSeries.readings.last?.plottedValue == 195)
ok("cholesterol fell between 2021 and 2025",
   (cholSeries.delta ?? 0) < 0)

let altSeries = series.first { $0.id == "alt" }!
ok("latest ALT is the 2025 reading", altSeries.latest?.value == 28)
ok("previous ALT is the 2023 reading", altSeries.previous?.value == 41)
ok("delta = 28 − 41", altSeries.delta == -13)
ok("percent change ≈ −31.7%", abs((altSeries.percentChange ?? 0) + 31.7) < 0.2)

print("\n▸ Nothing is silently dropped")
let odd = [mk("Zorblatt Factor", 7, "arb", day(2024, 1, 1)),
           mk("Zorblatt Factor", 9, "arb", day(2025, 1, 1))]
let oddSeries = SeriesBuilder.build(from: odd)
ok("unrecognised analyte still forms a series", oddSeries.count == 1)
ok("it keeps the lab's own wording", oddSeries.first?.name == "Zorblatt Factor")
ok("and still tracks over time", oddSeries.first?.readings.count == 2)

print("\n▸ Unreconcilable units are flagged, not hidden")
let badUnit = [mk("Creatinine", 1.0, "mg/dL", day(2024, 1, 1)),
               mk("Creatinine", 90, "furlongs", day(2025, 1, 1))]
let badSeries = SeriesBuilder.build(from: badUnit).first!
ok("series carries an unreconciled-units warning", badSeries.hasUnreconciledUnits)
ok("the odd point still appears", badSeries.readings.count == 2)

// ── Round-trip ───────────────────────────────────────────────────────────────
print("\n▸ Codable round-trip")
let app = AppData(reports: [LabReport(date: day(2025,1,7), labName: "Dr Lal PathLabs")],
                  readings: mixed)
let back = try! JSONCoding.decoder.decode(
    AppData.self, from: try! JSONCoding.encoder.encode(app))
ok("survives encode → decode unchanged", back == app)
ok("sub-second precision preserved",
   back.reports.first!.importedAt == app.reports.first!.importedAt)

// Whole-second timestamps from an older build must still load.
let legacy = #"{"reports":[],"readings":[],"schemaVersion":1}"#.data(using: .utf8)!
ok("decodes a document with no dates at all",
   (try? JSONCoding.decoder.decode(AppData.self, from: legacy)) != nil)

print("\n" + String(repeating: "─", count: 58))
print(failed == 0 ? "✅ ALL \(passed) TESTS PASSED" : "❌ \(failed) FAILED, \(passed) passed")
print(String(repeating: "─", count: 58) + "\n")
exit(failed == 0 ? 0 : 1)
